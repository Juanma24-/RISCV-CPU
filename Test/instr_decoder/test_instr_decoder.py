#!/usr/bin/env python3
"""
Cocotb Testbench – RV32I Instruction Decoder
=============================================

IMPORTANT – if you see a RecordAccessor RuntimeError:
  1. Run only probe_dut_signals first:
       make TESTCASE=probe_dut_signals
  2. Look for lines that start with "SIGNAL:" in the log.
  3. Find any signal that contains "op_reg" or "lui" and note the
     characters between "op_reg_o" and "lui_op".
  4. Add that separator string to _EXTRA_SEPARATORS below and re-run.

Common patterns seen in the wild
  Simulator          Example flat name
  -------------------------------------------------------
  GHDL               op_reg_o_lui_op
  NVC                op_reg_o_lui_op
  Questa / Modelsim  op_reg_o_lui_op  OR  op_reg_o(lui_op)
  Xcelium            op_reg_o__DOT__lui_op
  Riviera            op_reg_o.lui_op   (true sub-handle)
"""

import cocotb
from cocotb.triggers import RisingEdge, ClockCycles, Timer
from dataclasses import dataclass
from typing import Optional, Dict, List

# ── If auto-detection still fails, add your separator here ────────────────
_EXTRA_SEPARATORS: List[str] = []   # e.g. ["(", "/"]
# ──────────────────────────────────────────────────────────────────────────


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _read(signal) -> int:
    try:
        return int(signal.value)
    except Exception:
        return -1


def sign_extend(value: int, bits: int) -> int:
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)


def to_signed32(value: int) -> int:
    return sign_extend(int(value) & 0xFFFF_FFFF, 32)


def _all_dut_names(dut) -> List[str]:
    return sorted(n for n in dir(dut) if not n.startswith("_"))
    #return sorted(n for n in dir(dut))


# ---------------------------------------------------------------------------
# RecordAccessor  – auto-detects simulator flattening separator
# ---------------------------------------------------------------------------

_BUILTIN_SEPARATORS = ["_", "__", "__DOT__", "___"]   # tried before extras


class RecordAccessor:
    """
    Uniform field access for a flattened VHDL record output port.

    Usage
    -----
        ra = RecordAccessor(dut, "op_branch_o",
                            ["beq_op","bne_op", ...])
        ra.detect(all_signal_names)   # pass list once per test
        value = ra["beq_op"]          # returns int
    """

    def __init__(self, dut, port_name: str, fields: List[str]):
        self._dut       = dut
        self._port      = port_name
        self._fields    = fields
        self._sep       = None          # set by detect()
        self._hier      = False         # True when real sub-handle works
        self._cache: Dict[str, object] = {}

    # ------------------------------------------------------------------
    def detect(self, all_names: List[str]):
        """
        Determine the separator used by the simulator.
        `all_names` is the list returned by _all_dut_names(dut).
        """
        self._sep   = None
        self._hier  = False
        self._cache = {}

        probe = self._fields[0]

        # 1. True hierarchical sub-handle (Riviera, some Questa configs)
        try:
            parent = getattr(self._dut, self._port)
            child  = getattr(parent, probe)
            _      = int(child.value)
            self._hier = True
            self._sep  = "."
            cocotb.log.info(
                f"[RecordAccessor] {self._port}: hierarchical sub-handle (.)")
            return
        except Exception:
            pass

        # 2. Scan all visible signal names for a match on the probe field
        all_seps = _BUILTIN_SEPARATORS + _EXTRA_SEPARATORS
        for sep in all_seps:
            candidate = f"{self._port}{sep}{probe}"
            if candidate in all_names:
                # Verify it is actually readable
                try:
                    sig = getattr(self._dut, candidate)
                    _   = int(sig.value)
                    self._sep = sep
                    cocotb.log.info(
                        f"[RecordAccessor] {self._port}: "
                        f"separator='{sep}'  "
                        f"(matched '{candidate}')")
                    return
                except Exception:
                    pass

        # 3. Fallback: search all_names for anything containing both
        #    the port name and the probe field (catches unusual formats)
        port_lower  = self._port.lower()
        probe_lower = probe.lower()
        candidates  = [n for n in all_names
                       if port_lower in n.lower() and probe_lower in n.lower()]

        if candidates:
            # Derive separator from the first hit
            hit = candidates[0]
            # strip leading port name and trailing field name
            inner = hit[len(self._port):-len(probe)]
            try:
                sig = getattr(self._dut, hit)
                _   = int(sig.value)
                self._sep = inner
                cocotb.log.warning(
                    f"[RecordAccessor] {self._port}: "
                    f"inferred separator='{inner}' from '{hit}' "
                    f"– add to _EXTRA_SEPARATORS if you see issues")
                return
            except Exception:
                pass

        # 4. Give up with a helpful diagnostic
        related = [n for n in all_names if self._port.lower() in n.lower()]
        msg = (
            f"[RecordAccessor] Cannot resolve '{self._port}.{probe}' on DUT "
            f"'{self._dut._name}'.\n"
            f"  Tried separators : {all_seps}\n"
            f"  Signals containing '{self._port}': "
            f"{related if related else '(none – check port name)'}\n"
            f"  First 60 DUT signals: {all_names[:60]}\n"
            f"  ➜  Add the correct separator to _EXTRA_SEPARATORS at the "
            f"top of this file and re-run."
        )
        raise RuntimeError(msg)

    # ------------------------------------------------------------------
    def _handle(self, field: str):
        if field not in self._cache:
            if self._hier:
                self._cache[field] = getattr(
                    getattr(self._dut, self._port), field)
            else:
                flat = f"{self._port}{self._sep}{field}"
                self._cache[field] = getattr(self._dut, flat)
        return self._cache[field]

    def __getitem__(self, field: str) -> int:
        return _read(self._handle(field))


# ---------------------------------------------------------------------------
# Module-level accessor registry  (initialised per test via _init_accessors)
# ---------------------------------------------------------------------------

_RA: Dict[str, RecordAccessor] = {}


def _init_accessors(dut):
    """Create RecordAccessors and run detection. Call at the top of each test."""
    global _RA
    names = _all_dut_names(dut)

    _RA["op_reg"]    = RecordAccessor(dut, "op_reg_o",
                           ["lui_op", "auipc_op"])
    _RA["op_branch"] = RecordAccessor(dut, "op_branch_o",
                           ["beq_op","bne_op","blt_op","bge_op",
                            "bltu_op","bgeu_op","jal_op","jalr_op"])
    _RA["op_lsu"]    = RecordAccessor(dut, "op_lsu_o",
                           ["lb_op","lh_op","lw_op","lbu_op","lhu_op",
                            "sb_op","sh_op","sw_op"])
    _RA["op_alu"]    = RecordAccessor(dut, "op_alu_o",
                           ["add_op","sub_op","slt_op","sltu_op",
                            "srl_op","sll_op","sra_op","xor_op",
                            "and_op","or_op"])
    _RA["op_err"]    = RecordAccessor(dut, "op_err_o",
                           ["undef_opcode","undef_f3code","undef_f7code"])

    for ra in _RA.values():
        ra.detect(names)


# ---------------------------------------------------------------------------
# Expected-output dataclasses
# Fields left as None are silently skipped.
# ---------------------------------------------------------------------------

@dataclass
class ExpOpReg:
    lui_op   : Optional[int] = None
    auipc_op : Optional[int] = None

@dataclass
class ExpOpBranch:
    beq_op  : Optional[int] = None
    bne_op  : Optional[int] = None
    blt_op  : Optional[int] = None
    bge_op  : Optional[int] = None
    bltu_op : Optional[int] = None
    bgeu_op : Optional[int] = None
    jal_op  : Optional[int] = None
    jalr_op : Optional[int] = None

@dataclass
class ExpOpLSU:
    lb_op  : Optional[int] = None
    lh_op  : Optional[int] = None
    lw_op  : Optional[int] = None
    lbu_op : Optional[int] = None
    lhu_op : Optional[int] = None
    sb_op  : Optional[int] = None
    sh_op  : Optional[int] = None
    sw_op  : Optional[int] = None

@dataclass
class ExpOpALU:
    add_op  : Optional[int] = None
    sub_op  : Optional[int] = None
    slt_op  : Optional[int] = None
    sltu_op : Optional[int] = None
    srl_op  : Optional[int] = None
    sll_op  : Optional[int] = None
    sra_op  : Optional[int] = None
    xor_op  : Optional[int] = None
    and_op  : Optional[int] = None
    or_op   : Optional[int] = None

@dataclass
class ExpOpErr:
    undef_opcode : Optional[int] = None
    undef_f3code : Optional[int] = None
    undef_f7code : Optional[int] = None


# Convenience: fully-zeroed records
OP_REG_NOP    = ExpOpReg   (lui_op=0, auipc_op=0)
OP_BRANCH_NOP = ExpOpBranch(beq_op=0, bne_op=0, blt_op=0, bge_op=0,
                             bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0)
OP_LSU_NOP    = ExpOpLSU   (lb_op=0, lh_op=0, lw_op=0, lbu_op=0, lhu_op=0,
                             sb_op=0, sh_op=0, sw_op=0)
OP_ALU_NOP    = ExpOpALU   (add_op=0, sub_op=0, slt_op=0, sltu_op=0,
                             srl_op=0, sll_op=0, sra_op=0, xor_op=0,
                             and_op=0, or_op=0)
OP_ERR_OK     = ExpOpErr   (undef_opcode=0, undef_f3code=0, undef_f7code=0)


# ---------------------------------------------------------------------------
# Core assertion engine
# ---------------------------------------------------------------------------

def _check_record(failures: list, ra: RecordAccessor, exp) -> None:
    for fname, expected in vars(exp).items():
        if expected is None:
            continue
        got = ra[fname]
        if got != expected:
            failures.append(
                f"  {ra._port}.{fname}: expected {expected}, got {got}")


def assert_outputs(
    dut,
    instr_hex : int,
    desc      : str,
    *,
    op_reg    : Optional[ExpOpReg]    = None,
    op_branch : Optional[ExpOpBranch] = None,
    op_lsu    : Optional[ExpOpLSU]    = None,
    op_alu    : Optional[ExpOpALU]    = None,
    op_err    : Optional[ExpOpErr]    = None,
    imm       : Optional[int]         = None,
    imm_valid : Optional[int]         = None,
    rs1       : Optional[int]         = None,
    rs2       : Optional[int]         = None,
    rd        : Optional[int]         = None,
) -> None:
    failures = []

    if op_reg    is not None: _check_record(failures, _RA["op_reg"],    op_reg)
    if op_branch is not None: _check_record(failures, _RA["op_branch"], op_branch)
    if op_lsu    is not None: _check_record(failures, _RA["op_lsu"],    op_lsu)
    if op_alu    is not None: _check_record(failures, _RA["op_alu"],    op_alu)
    if op_err    is not None: _check_record(failures, _RA["op_err"],    op_err)

    if imm is not None:
        got = to_signed32(_read(dut.imm_o))
        if got != imm:
            failures.append(
                f"  imm_o: expected {imm} (0x{imm & 0xFFFF_FFFF:08X}), "
                f"got {got} (0x{got & 0xFFFF_FFFF:08X})")

    if imm_valid is not None:
        got = _read(dut.imm_valid_o)
        if got != imm_valid:
            failures.append(f"  imm_valid_o: expected {imm_valid}, got {got}")

    for name, expected, reader in [
        ("rs1_o", rs1, lambda: _read(dut.rs1_o)),
        ("rs2_o", rs2, lambda: _read(dut.rs2_o)),
        ("rd_o",  rd,  lambda: _read(dut.rd_o)),
    ]:
        if expected is not None:
            got = reader()
            if got != expected:
                failures.append(f"  {name}: expected {expected}, got {got}")

    header = f"[0x{instr_hex:08X}] {desc}"
    if failures:
        msg = "\n".join([f"FAIL {header}"] + failures)
        cocotb.log.error(msg)
        assert False, msg
    else:
        cocotb.log.info(f"PASS {header}")


# ---------------------------------------------------------------------------
# Drive one instruction and wait 1 ns for combinational outputs to settle
# ---------------------------------------------------------------------------

async def drive_and_check(dut, instr_hex: int, desc: str, **kwargs):
    await RisingEdge(dut.clk_i)
    dut.instr_i.value = instr_hex
    cocotb.log.info(f"Driving 0x{instr_hex:08X}  {desc}")
    await Timer(1, unit="ns")
    await RisingEdge(dut.clk_i)
    await Timer(1, unit="ns")
    assert_outputs(dut, instr_hex, desc, **kwargs)


# ---------------------------------------------------------------------------
# Clock & reset
# ---------------------------------------------------------------------------

async def generate_clock(dut):
    while True:
        dut.clk_i.value = 0
        await Timer(5, unit="ns")
        dut.clk_i.value = 1
        await Timer(5, unit="ns")


async def reset_dut(dut, cycles: int = 5):
    dut.rst_i.value   = 0
    dut.instr_i.value = 0x00000013
    await ClockCycles(dut.clk_i, cycles, RisingEdge)
    dut.rst_i.value = 1
    await RisingEdge(dut.clk_i)
    cocotb.log.info("Reset de-asserted.")


# ===========================================================================
# PROBE TEST – run this first to identify the correct separator
# ===========================================================================

@cocotb.test()
async def probe_dut_signals(dut):
    """
    Prints every signal handle visible on the DUT, then attempts to
    initialise all RecordAccessors.  Always passes even when detection
    fails, so you can read the log without the test aborting.

    Run with:  make TESTCASE=probe_dut_signals
    """
    cocotb.start_soon(generate_clock(dut))
    await Timer(1, unit="ns")

    names = _all_dut_names(dut)
    cocotb.log.info(f"=== DUT '{dut._name}' – {len(names)} visible signals ===")
    for n in names:
        cocotb.log.info(f"  SIGNAL: {n}")
    cocotb.log.info("=== End of signal list ===")

    # Attempt accessor detection and log the result
    try:
        _init_accessors(dut)
        cocotb.log.info("RecordAccessor detection SUCCEEDED for all records.")
    except RuntimeError as e:
        cocotb.log.warning(f"RecordAccessor detection FAILED:\n{e}")
        cocotb.log.warning(
            "See the SIGNAL list above to find the correct separator, "
            "then add it to _EXTRA_SEPARATORS at the top of this file.")


# ===========================================================================
# TEST 1 – Reset behaviour
# ===========================================================================

@cocotb.test()
async def test_reset_outputs(dut):
    """While rst_i=0 all outputs must be in a safe/NOP state."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)

    dut.rst_i.value   = 0
    dut.instr_i.value = 0x00000000
    await ClockCycles(dut.clk_i, 3, RisingEdge)
    await Timer(1, unit="ns")

    assert_outputs(
        dut, 0x00000000, "Reset active – outputs NOP/safe",
        op_branch = OP_BRANCH_NOP,
        op_lsu    = OP_LSU_NOP,
        op_err    = OP_ERR_OK,
    )


# ===========================================================================
# TEST 2 – R-type instructions  (opcode = 0b011_0011)
# ===========================================================================

@cocotb.test()
async def test_r_type(dut):
    """All ten R-type ops. One ALU flag high; all branch/LSU/err flags low."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x003100B3, "ADD  x1,x2,x3",  ExpOpALU(add_op=1,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0), 2, 3, 1),
        (0x403100B3, "SUB  x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=1, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0), 2, 3, 1),
        (0x003110B3, "SLL  x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=0, sll_op=1, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0), 2, 3, 1),
        (0x003120B3, "SLT  x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=1, sltu_op=0), 2, 3, 1),
        (0x003130B3, "SLTU x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=1), 2, 3, 1),
        (0x00A4C433, "XOR  x8,x9,x10", ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=1, and_op=0, or_op=0, slt_op=0, sltu_op=0), 9, 10, 8),
        (0x003150B3, "SRL  x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=1, sra_op=0, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0), 2, 3, 1),
        (0x403150B3, "SRA  x1,x2,x3",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=1, xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0), 2, 3, 1),
        (0x007362B3, "OR   x5,x6,x7",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=0, or_op=1, slt_op=0, sltu_op=0), 6, 7, 5),
        (0x007372B3, "AND  x5,x6,x7",  ExpOpALU(add_op=0,  sub_op=0, sll_op=0, srl_op=0, sra_op=0, xor_op=0, and_op=1, or_op=0, slt_op=0, sltu_op=0), 6, 7, 5),
    ]

    for instr_hex, desc, alu, r1, r2, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_alu    = alu,
            op_reg    = OP_REG_NOP,
            op_branch = OP_BRANCH_NOP,
            op_lsu    = OP_LSU_NOP,
            op_err    = OP_ERR_OK,
            imm_valid = 0, rs1=r1, rs2=r2, rd=r_d,
        )


# ===========================================================================
# TEST 3 – I-type ALU  (opcode = 0b001_0011)
# ===========================================================================

@cocotb.test()
async def test_i_type_alu(dut):
    """ADDI/SLTI/SLTIU/XORI/ORI/ANDI/SLLI/SRLI/SRAI – immediate & ALU flags."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    # (instr_hex, desc, alu_dc, imm_val, rs1_val, rd_val)
    cases = [
        (0x00A28213, "ADDI x4,x5,+10",   ExpOpALU(add_op=1,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),  10,  5, 4),
        (0xFFF08093, "ADDI x1,x1,-1",    ExpOpALU(add_op=1,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),  -1,  1, 1),
        (0x00000013, "NOP (ADDI x0,x0,0)",ExpOpALU(add_op=1, sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),   0,  0, 0),
        (0x0051A113, "SLTI  x2,x3,5",    ExpOpALU(add_op=0,  sub_op=0, slt_op=1, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),   5,  3, 2),
        (0x0051B113, "SLTIU x2,x3,5",    ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=1, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),   5,  3, 2),
        (0xFFF1C113, "XORI  x2,x3,-1",   ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=1, and_op=0, or_op=0),  -1,  3, 2),
        (0x0FF1E113, "ORI   x2,x3,0xFF", ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=1), 255,  3, 2),
        (0x0FF1F113, "ANDI  x2,x3,0xFF", ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=0, xor_op=0, and_op=1, or_op=0), 255,  3, 2),
        (0x00411093, "SLLI  x1,x2,4",    ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=1, sra_op=0, xor_op=0, and_op=0, or_op=0),   4,  2, 1),
        (0x00415093, "SRLI  x1,x2,4",    ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=1, sll_op=0, sra_op=0, xor_op=0, and_op=0, or_op=0),   4,  2, 1),
        (0x40415093, "SRAI  x1,x2,4",    ExpOpALU(add_op=0,  sub_op=0, slt_op=0, sltu_op=0, srl_op=0, sll_op=0, sra_op=1, xor_op=0, and_op=0, or_op=0),   4,  2, 1),
    ]

    for instr_hex, desc, alu, imm_val, r1, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_alu    = alu,
            op_reg    = OP_REG_NOP,
            op_branch = OP_BRANCH_NOP,
            op_lsu    = OP_LSU_NOP,
            op_err    = OP_ERR_OK,
            imm_valid = 1, imm=imm_val, rs1=r1, rd=r_d,
        )


# ===========================================================================
# TEST 4 – U-type: LUI / AUIPC
# ===========================================================================

@cocotb.test(skip=False)
async def test_u_type(dut):
    """LUI→lui_op=1; AUIPC→auipc_op=1. Lower 12 imm bits must be zero."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    await drive_and_check(
        dut, 0x12345637, "LUI x12, 0x12345",
        op_reg    = ExpOpReg(lui_op=1, auipc_op=0),
        op_alu    = OP_ALU_NOP, op_branch = OP_BRANCH_NOP,
        op_lsu    = OP_LSU_NOP, op_err    = OP_ERR_OK,
        imm_valid=1, imm=0x12345000, rs1=0, rs2=0, rd=12,
    )

    await drive_and_check(
        dut, 0x800000B7, "LUI x1, 0x80000  (sign bit)",
        op_reg    = ExpOpReg(lui_op=1, auipc_op=0),
        op_alu    = OP_ALU_NOP, op_branch = OP_BRANCH_NOP,
        op_lsu    = OP_LSU_NOP, op_err    = OP_ERR_OK,
        imm_valid=1, imm=sign_extend(0x80000000, 32), rd=1,
    )

    await drive_and_check(
        dut, 0x00001117, "AUIPC x2, 0x1",
        op_reg    = ExpOpReg(lui_op=0, auipc_op=1),
        op_alu    = OP_ALU_NOP, op_branch = OP_BRANCH_NOP,
        op_lsu    = OP_LSU_NOP, op_err    = OP_ERR_OK,
        imm_valid=1, imm=0x1000, rs1=0, rs2=0, rd=2,
    )


# ===========================================================================
# TEST 5 – Load instructions  (opcode = 0b000_0011)
# ===========================================================================

@cocotb.test(skip=False)
async def test_load_instructions(dut):
    """LB/LH/LW/LBU/LHU: one load flag high, all store flags low."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x0043A303, "LW  x6, 4(x7)",          ExpOpLSU(lw_op=1,  lb_op=0, lh_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0, sw_op=0),  4, 7, 6),
        (0xFFC12083, "LW  x1,-4(x2) neg",       ExpOpLSU(lw_op=1,  lb_op=0, lh_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0, sw_op=0), -4, 2, 1),
        (0x00211083, "LH  x1, 2(x2)",           ExpOpLSU(lh_op=1,  lb_op=0, lw_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0, sw_op=0),  2, 2, 1),
        (0x00110083, "LB  x1, 1(x2)",           ExpOpLSU(lb_op=1,  lh_op=0, lw_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0, sw_op=0),  1, 2, 1),
        (0x00215083, "LHU x1, 2(x2)",           ExpOpLSU(lhu_op=1, lb_op=0, lh_op=0, lw_op=0,  lbu_op=0, sb_op=0, sh_op=0, sw_op=0),  2, 2, 1),
        (0x00114083, "LBU x1, 1(x2)",           ExpOpLSU(lbu_op=1, lb_op=0, lh_op=0, lw_op=0,  lhu_op=0, sb_op=0, sh_op=0, sw_op=0),  1, 2, 1),
    ]

    for instr_hex, desc, lsu, imm_val, r1, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_lsu    = lsu,
            op_reg    = OP_REG_NOP, op_branch = OP_BRANCH_NOP,
            op_err    = OP_ERR_OK,
            imm_valid=1, imm=imm_val, rs1=r1, rs2=0, rd=r_d,
        )


# ===========================================================================
# TEST 6 – Store instructions  (opcode = 0b010_0011)
# ===========================================================================

@cocotb.test(skip=False)
async def test_store_instructions(dut):
    """SB/SH/SW: split S-immediate reassembled correctly; one store flag high."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x0084A423, "SW x8, 8(x9)",        ExpOpLSU(sw_op=1, lb_op=0, lh_op=0, lw_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0),  8, 9, 8),
        (0xFE84AC23, "SW x8,-8(x9) neg",    ExpOpLSU(sw_op=1, lb_op=0, lh_op=0, lw_op=0, lbu_op=0, lhu_op=0, sb_op=0, sh_op=0), -8, 9, 8),
        (0x00849223, "SH x8, 4(x9)",        ExpOpLSU(sh_op=1, lb_op=0, lh_op=0, lw_op=0, lbu_op=0, lhu_op=0, sb_op=0, sw_op=0),  4, 9, 8),
        (0x008480A3, "SB x8, 1(x9)",        ExpOpLSU(sb_op=1, lb_op=0, lh_op=0, lw_op=0, lbu_op=0, lhu_op=0, sh_op=0, sw_op=0),  1, 9, 8),
    ]

    for instr_hex, desc, lsu, imm_val, r1, r2 in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_lsu    = lsu,
            op_reg    = OP_REG_NOP, op_branch = OP_BRANCH_NOP,
            op_err    = OP_ERR_OK,
            imm_valid=1, imm=imm_val, rs1=r1, rs2=r2,
        )


# ===========================================================================
# TEST 7 – Branch instructions  (opcode = 0b110_0011)
# ===========================================================================

@cocotb.test(skip=False)
async def test_branch_instructions(dut):
    """BEQ/BNE/BLT/BGE/BLTU/BGEU: one branch flag high; forward and backward."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x00B50863, "BEQ  x10,x11,+16", ExpOpBranch(beq_op=1,  bne_op=0, blt_op=0, bge_op=0, bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),  16, 10, 11),
        (0x00209463, "BNE  x1,x2,+8",    ExpOpBranch(beq_op=0,  bne_op=1, blt_op=0, bge_op=0, bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),   8,  1,  2),
        (0x0041C663, "BLT  x3,x4,+12",   ExpOpBranch(beq_op=0,  bne_op=0, blt_op=1, bge_op=0, bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),  12,  3,  4),
        (0x0041D663, "BGE  x3,x4,+12",   ExpOpBranch(beq_op=0,  bne_op=0, blt_op=0, bge_op=1, bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),  12,  3,  4),
        (0x0041E463, "BLTU x3,x4,+8",    ExpOpBranch(beq_op=0,  bne_op=0, blt_op=0, bge_op=0, bltu_op=1, bgeu_op=0, jal_op=0, jalr_op=0),   8,  3,  4),
        (0x0041F463, "BGEU x3,x4,+8",    ExpOpBranch(beq_op=0,  bne_op=0, blt_op=0, bge_op=0, bltu_op=0, bgeu_op=1, jal_op=0, jalr_op=0),   8,  3,  4),
        (0xFE208CE3, "BEQ  x1,x2,-8 bwd",ExpOpBranch(beq_op=1,  bne_op=0, blt_op=0, bge_op=0, bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),  -8,  1,  2),
    ]

    for instr_hex, desc, br, imm_val, r1, r2 in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_branch = br,
            op_reg    = OP_REG_NOP, op_lsu = OP_LSU_NOP,
            op_err    = OP_ERR_OK,
            imm_valid=1, imm=imm_val, rs1=r1, rs2=r2,
        )


# ===========================================================================
# TEST 8 – JAL  (opcode = 0b110_1111)
# ===========================================================================

@cocotb.test(skip=False)
async def test_jal(dut):
    """JAL: jal_op=1, jalr_op=0. Forward, zero and backward offsets."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x010000EF, "JAL x1,+16",        16, 1),
        (0x0000006F, "JAL x0,0 inf-loop",  0, 0),
        (0xFFDFF0EF, "JAL x1,-4 bwd",     -4, 1),
    ]

    for instr_hex, desc, imm_val, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_branch = ExpOpBranch(beq_op=0, bne_op=0, blt_op=0, bge_op=0,
                                    bltu_op=0, bgeu_op=0, jal_op=1, jalr_op=0),
            op_reg    = OP_REG_NOP, op_lsu = OP_LSU_NOP, op_err = OP_ERR_OK,
            imm_valid=1, imm=imm_val, rd=r_d,
        )


# ===========================================================================
# TEST 9 – JALR  (opcode = 0b110_0111, funct3=000)
# ===========================================================================

@cocotb.test(skip=False)
async def test_jalr(dut):
    """JALR: jalr_op=1, jal_op=0.  Normal call and RET (rd=x0)."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x000100E7, "JALR x1,0(x2)",     0, 2, 1),
        (0x00008067, "JALR x0,0(x1) RET", 0, 1, 0),
    ]

    for instr_hex, desc, imm_val, r1, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_branch = ExpOpBranch(beq_op=0, bne_op=0, blt_op=0, bge_op=0,
                                    bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=1),
            op_reg    = OP_REG_NOP, op_lsu = OP_LSU_NOP, op_err = OP_ERR_OK,
            imm_valid=1, imm=imm_val, rs1=r1, rd=r_d,
        )


# ===========================================================================
# TEST 10 – op_err_t fields
# ===========================================================================

@cocotb.test(skip=False)
async def test_error_flags(dut):
    """undef_opcode / undef_f3code / undef_f7code each asserted in isolation."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    # undef_opcode
    for instr_hex, desc in [
        (0x0000007F, "opcode=0x7F (reserved)"),
        (0x00000020, "opcode=0x01 (undefined)"),
        (0xFFFFFFFF, "all-ones"),
    ]:
        await drive_and_check(
            dut, instr_hex, f"undef_opcode: {desc}",
            op_err    = ExpOpErr(undef_opcode=1, undef_f3code=0, undef_f7code=0),
            op_branch = OP_BRANCH_NOP, op_lsu = OP_LSU_NOP,
        )

    # undef_f3code: R-type opcode, funct3=011 (undefined in RV32I)
    await drive_and_check(
        dut, 0x0001B003, "undef_f3code: R-type funct3=011",
        op_err    = ExpOpErr(undef_opcode=0, undef_f3code=1, undef_f7code=0),
        op_branch = OP_BRANCH_NOP, op_lsu = OP_LSU_NOP,
    )

    # undef_f7code: SLLI encoding with funct7=0100000 (illegal for funct3=001)
    await drive_and_check(
        dut, 0x40411093, "undef_f7code: SLLI funct7=0100000",
        op_err    = ExpOpErr(undef_opcode=0, undef_f3code=0, undef_f7code=1),
        op_branch = OP_BRANCH_NOP, op_lsu = OP_LSU_NOP,
    )


# ===========================================================================
# TEST 11 – rd=x0 suppresses register write
# ===========================================================================

@cocotb.test(skip=False)
async def test_rd_x0_suppressed(dut):
    """op_reg must be NOP when rd=x0, regardless of instruction type."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    cases = [
        (0x00508013, "ADDI x0,x1,5  (I-type rd=x0)", 0),
        (0x00208033, "ADD  x0,x1,x2 (R-type rd=x0)", 0),
        (0x00001037, "LUI  x0,1      (U-type rd=x0)", 0),
    ]

    for instr_hex, desc, r_d in cases:
        await drive_and_check(
            dut, instr_hex, desc,
            op_reg    = OP_REG_NOP,
            op_branch = OP_BRANCH_NOP, op_lsu = OP_LSU_NOP,
            op_err    = OP_ERR_OK, rd=r_d,
        )


# ===========================================================================
# TEST 12 – Back-to-back stream (stale-state regression)
# ===========================================================================

@cocotb.test(skip=False)
async def test_back_to_back_stream(dut):
    """Dense varied stream; checks cross-type flag de-assertion every cycle."""
    cocotb.start_soon(generate_clock(dut))
    _init_accessors(dut)
    await reset_dut(dut)

    stream = [
        (0x003100B3, "ADD  x1,x2,x3",    dict(
            op_alu=ExpOpALU(add_op=1, sub_op=0, sll_op=0, srl_op=0, sra_op=0,
                            xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0),
            op_branch=OP_BRANCH_NOP, op_lsu=OP_LSU_NOP,
            op_err=OP_ERR_OK, imm_valid=0, rs1=2, rs2=3, rd=1)),

        (0x00A28213, "ADDI x4,x5,10",    dict(
            op_alu=ExpOpALU(add_op=1, sub_op=0, sll_op=0, srl_op=0, sra_op=0,
                            xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0),
            op_branch=OP_BRANCH_NOP, op_lsu=OP_LSU_NOP,
            op_err=OP_ERR_OK, imm_valid=1, imm=10, rs1=5, rd=4)),

        (0x0043A303, "LW   x6,4(x7)",    dict(
            op_lsu=ExpOpLSU(lw_op=1, lb_op=0, lh_op=0, lbu_op=0, lhu_op=0,
                            sb_op=0, sh_op=0, sw_op=0),
            op_branch=OP_BRANCH_NOP, op_err=OP_ERR_OK,
            imm_valid=1, imm=4, rs1=7, rd=6)),

        (0x0084A423, "SW   x8,8(x9)",    dict(
            op_lsu=ExpOpLSU(sw_op=1, lb_op=0, lh_op=0, lw_op=0, lbu_op=0,
                            lhu_op=0, sb_op=0, sh_op=0),
            op_branch=OP_BRANCH_NOP, op_err=OP_ERR_OK,
            imm_valid=1, imm=8, rs1=9, rs2=8)),

        (0x00B50863, "BEQ  x10,x11,+16", dict(
            op_branch=ExpOpBranch(beq_op=1, bne_op=0, blt_op=0, bge_op=0,
                                  bltu_op=0, bgeu_op=0, jal_op=0, jalr_op=0),
            op_lsu=OP_LSU_NOP, op_err=OP_ERR_OK,
            imm_valid=1, imm=16, rs1=10, rs2=11)),

        (0x12345637, "LUI  x12,0x12345", dict(
            op_reg=ExpOpReg(lui_op=1, auipc_op=0),
            op_alu=OP_ALU_NOP, op_branch=OP_BRANCH_NOP,
            op_lsu=OP_LSU_NOP, op_err=OP_ERR_OK,
            imm_valid=1, imm=0x12345000, rd=12)),

        (0x010000EF, "JAL  x1,+16",      dict(
            op_branch=ExpOpBranch(beq_op=0, bne_op=0, blt_op=0, bge_op=0,
                                  bltu_op=0, bgeu_op=0, jal_op=1, jalr_op=0),
            op_lsu=OP_LSU_NOP, op_err=OP_ERR_OK,
            imm_valid=1, imm=16, rd=1)),

        (0x00000013, "NOP",              dict(
            op_alu=ExpOpALU(add_op=1, sub_op=0, sll_op=0, srl_op=0, sra_op=0,
                            xor_op=0, and_op=0, or_op=0, slt_op=0, sltu_op=0),
            op_branch=OP_BRANCH_NOP, op_lsu=OP_LSU_NOP,
            op_err=OP_ERR_OK, imm_valid=1, imm=0, rs1=0, rs2=0, rd=0)),
    ]

    for instr_hex, desc, checks in stream:
        await drive_and_check(dut, instr_hex, desc, **checks)

    await ClockCycles(dut.clk_i, 2, RisingEdge)
    cocotb.log.info("Back-to-back stream PASSED.")

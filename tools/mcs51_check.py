# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Fail-closed MCS-51 instruction subset for compiled policy checks, not hardware simulation."""
import hashlib
import re

def identifier(name):
    return name if len(name) <= 30 else "S_" + hashlib.sha256(name.lower().encode()).hexdigest()[:24]

def listing_symbols(listing):
    return {m[1].lower(): int(m[2], 16)
            for m in re.finditer(r"(?mi)^(\w+)\s+(?:CODE|DATA|IDATA|BIT|NUMBER)\s+([0-9A-F]+)\b", listing)}

class Machine:
    def __init__(self, code, symbols):
        self.code = code
        self.symbols = symbols
        self.ram = bytearray(256)
        self.sfr = bytearray(256)
        self.pc = 0
        self.calls = []
        self.stack = []
        self.hooks = {}

    def address(self, name):
        return self.symbols[identifier(name).lower()]

    def direct(self, address, value=None):
        area = self.ram if address < 128 else self.sfr
        if value is not None:
            area[address] = value & 255
        return area[address]

    def named(self, name, value=None):
        return self.direct(self.address(name), value)

    def bit(self, address, value=None):
        byte = (address & 0xF8) if address >= 128 else 0x20 + address // 8
        shift = address % 8
        if value is not None:
            old = self.direct(byte)
            self.direct(byte, (old & ~(1 << shift)) | (int(bool(value)) << shift))
        return (self.direct(byte) >> shift) & 1

    def flag(self, name, value=None):
        return self.bit(self.address(name), value)

    @property
    def a(self): return self.direct(0xE0)
    @a.setter
    def a(self, value): self.direct(0xE0, value)
    @property
    def carry(self): return self.bit(0xD7)
    @carry.setter
    def carry(self, value): self.bit(0xD7, value)

    def register(self, number, value=None):
        address = ((self.direct(0xD0) >> 3) & 3) * 8 + number
        if value is not None: self.ram[address] = value & 255
        return self.ram[address]

    def fetch(self):
        value = self.code[self.pc]
        self.pc += 1
        return value

    def relative(self):
        value = self.fetch()
        return value if value < 128 else value - 256

    def run(self, start, stop=(), limit=500):
        self.pc = self.address(start) if isinstance(start, str) else start
        stops = {self.address(name) if isinstance(name, str) else name for name in stop}
        for _ in range(limit):
            if self.pc in stops: return self.pc
            position = self.pc
            opcode = self.fetch()
            if opcode == 0x22:
                if not self.stack: return None
                self.pc = self.stack.pop()
            elif opcode in (0x02, 0x12) or opcode & 0x1F in (0x01, 0x11):
                call = opcode == 0x12 or opcode & 0x1F == 0x11
                if opcode in (0x02, 0x12):
                    target = (self.fetch() << 8) | self.fetch()
                else:
                    low = self.fetch()
                    target = (self.pc & 0xF800) | ((opcode & 0xE0) << 3) | low
                if call:
                    self.calls.append(target)
                    if target in self.hooks:
                        self.hooks[target](self)
                        continue
                    self.stack.append(self.pc)
                self.pc = target
            elif opcode == 0x74: self.a = self.fetch()
            elif opcode == 0x75:
                address, value = self.fetch(), self.fetch()
                self.direct(address, value)
            elif 0x78 <= opcode <= 0x7F: self.register(opcode - 0x78, self.fetch())
            elif opcode in (0x76, 0x77):
                self.ram[self.register(opcode - 0x76)] = self.fetch()
            elif opcode == 0xE5: self.a = self.direct(self.fetch())
            elif opcode in (0xE6, 0xE7): self.a = self.ram[self.register(opcode - 0xE6)]
            elif 0xE8 <= opcode <= 0xEF: self.a = self.register(opcode - 0xE8)
            elif opcode == 0xF5: self.direct(self.fetch(), self.a)
            elif opcode in (0xF6, 0xF7): self.ram[self.register(opcode - 0xF6)] = self.a
            elif 0xF8 <= opcode <= 0xFF: self.register(opcode - 0xF8, self.a)
            elif opcode == 0x85:
                source, destination = self.fetch(), self.fetch()
                self.direct(destination, self.direct(source))
            elif 0x88 <= opcode <= 0x8F: self.direct(self.fetch(), self.register(opcode - 0x88))
            elif 0xA8 <= opcode <= 0xAF: self.register(opcode - 0xA8, self.direct(self.fetch()))
            elif opcode in (0xA6, 0xA7):
                self.ram[self.register(opcode - 0xA6)] = self.direct(self.fetch())
            elif opcode == 0xA2: self.carry = self.bit(self.fetch())
            elif opcode == 0x92: self.bit(self.fetch(), self.carry)
            elif opcode in (0xC2, 0xD2): self.bit(self.fetch(), opcode == 0xD2)
            elif opcode in (0xC3, 0xD3): self.carry = opcode == 0xD3
            elif opcode == 0xB3: self.carry ^= 1
            elif opcode == 0xE4: self.a = 0
            elif opcode == 0xF4: self.a ^= 255
            elif opcode in (0x04, 0x14): self.a += 1 if opcode == 0x04 else -1
            elif 0x08 <= opcode <= 0x0F:
                number = opcode - 0x08
                self.register(number, self.register(number) + 1)
            elif opcode == 0x05:
                address = self.fetch()
                self.direct(address, self.direct(address) + 1)
            elif opcode in (0x94, 0x95, 0x96, 0x97) or 0x98 <= opcode <= 0x9F:
                value = self.fetch() if opcode == 0x94 else self.direct(self.fetch()) if opcode == 0x95 else self.ram[self.register(opcode - 0x96)] if opcode < 0x98 else self.register(opcode - 0x98)
                result = self.a - value - self.carry
                self.a = result
                self.carry = result < 0
            elif opcode in (0x24, 0x25, 0x34, 0x35):
                value = self.fetch() if opcode in (0x24, 0x34) else self.direct(self.fetch())
                result = self.a + value + (self.carry if opcode >= 0x34 else 0)
                self.a = result
                self.carry = result > 255
            elif opcode in (0x54, 0x55, 0x44, 0x45):
                value = self.fetch() if opcode % 2 == 0 else self.direct(self.fetch())
                self.a = self.a & value if opcode >= 0x54 else self.a | value
            elif 0x48 <= opcode <= 0x4F: self.a |= self.register(opcode - 0x48)
            elif 0x58 <= opcode <= 0x5F: self.a &= self.register(opcode - 0x58)
            elif 0x28 <= opcode <= 0x2F or 0x38 <= opcode <= 0x3F:
                value = self.register(opcode & 7)
                result = self.a + value + (self.carry if opcode >= 0x38 else 0)
                self.a = result
                self.carry = result > 255
            elif opcode == 0xC4: self.a = (self.a << 4) | (self.a >> 4)
            elif opcode in (0x13, 0x33):
                old, carry = self.a, self.carry
                self.a = (old >> 1) | (carry << 7) if opcode == 0x13 else (old << 1) | carry
                self.carry = old & 1 if opcode == 0x13 else old >> 7
            elif opcode == 0x84:
                divisor = self.direct(0xF0)
                if not divisor: raise ValueError("DIV AB by zero")
                quotient, remainder = divmod(self.a, divisor)
                self.a = quotient
                self.direct(0xF0, remainder)
                self.carry = 0
            elif opcode in (0x40, 0x50, 0x60, 0x70, 0x80):
                displacement = self.relative()
                condition = {0x40:self.carry == 1, 0x50:self.carry == 0,
                             0x60:self.a == 0, 0x70:self.a != 0, 0x80:True}[opcode]
                if condition: self.pc += displacement
            elif opcode in (0x20, 0x30):
                bit, displacement = self.fetch(), self.relative()
                if self.bit(bit) == (opcode == 0x20): self.pc += displacement
            elif 0xB8 <= opcode <= 0xBF or opcode in (0xB4, 0xB5):
                left = self.a if opcode in (0xB4, 0xB5) else self.register(opcode - 0xB8)
                right = self.direct(self.fetch()) if opcode == 0xB5 else self.fetch()
                displacement = self.relative()
                self.carry = left < right
                if left != right: self.pc += displacement
            else:
                raise ValueError(f"Unsupported checked opcode {opcode:#04x} at {position:#06x}")
        raise ValueError("Checked firmware did not terminate within instruction budget")

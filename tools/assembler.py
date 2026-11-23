# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Assemble expanded firmware with deterministic MCS-51 jump/call relaxation."""
from pathlib import Path
import re
import subprocess

from asm_frontend import Frontend


def assemble(source_root, entry, defines, executable, output):
    output=Path(output)
    output.mkdir(parents=True,exist_ok=True)
    original=Frontend(source_root,defines).compile(entry).splitlines()
    segments={}
    segment=0
    for index,line in enumerate(original):
        if re.match(r"^CSEG\s+AT\b",line,re.I):segment+=1
        segments[index]=segment
    source=original[:]
    seen=set()
    for attempt in range(16):
        signature="\n".join(source)
        if signature in seen:raise ValueError("Instruction relaxation failed to converge")
        seen.add(signature)
        (output/"firmware.asm").write_text(signature+"\n",encoding="ascii",newline="\n")
        result=subprocess.run([str(Path(executable).resolve()),"firmware.asm","firmware.hex","firmware.lst"],
                              cwd=output,capture_output=True)
        (output/"assembler.log").write_bytes(result.stdout+result.stderr)
        if result.returncode:
            raise RuntimeError("Assembler failed:\n"+(result.stdout+result.stderr).decode("latin-1")[:3000])
        listing=(output/"firmware.lst").read_text(encoding="latin-1")
        symbols={m[1].lower():(int(m[2],16),int(m[3])-1)
                 for m in re.finditer(r"(?m)^(\w+)\s+CODE\s+([0-9A-F]{4})\s+(\d+)",listing)}
        locations={int(m[1])-1:int(m[2],16)
                   for m in re.finditer(r"(?m)^\s*(\d+):\s+([0-9A-F]{4})\s+",listing)}
        updated=source[:]
        for index,line in enumerate(original):
            match=re.fullmatch(r"(call|jmp)\s+(\w+)",line,re.I)
            if not match:continue
            target,targetline=symbols[match[2].lower()]
            position=locations[index]
            same=segments[index]==segments[targetline]
            page=((position+2)&0xF800)==(target&0xF800)
            if match[1].lower()=="call":
                instruction="acall" if same and page else "lcall"
            else:
                displacement=target-(position+2)
                instruction="sjmp" if same and -128<=displacement<=127 else "ajmp" if same and page else "ljmp"
            updated[index]=instruction+" "+match[2]
        if updated==source:
            return output/"firmware.hex"
        source=updated
    raise ValueError("Instruction relaxation exceeded pass limit")

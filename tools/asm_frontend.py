# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Compasless contributors
"""Expand the firmware's assembly dialect for a standard MCS-51 assembler."""
from pathlib import Path
import hashlib
import re


TOKEN = re.compile(r'\s*(0[xX][0-9a-fA-F]+|[0-9][0-9a-fA-F]*[hH]|[01]+[bB]|[0-9]+|'
                   r'"[^"]*"|\'[^\']*\'|[A-Za-z_]\w*|==|!=|<>|<=|>=|[()+*/%<>=~&|^.,-])')
PREC = {"or":1,"|":1,"xor":2,"^":2,"and":3,"&":3,
        "=":4,"==":4,"!=":4,"<>":4,"<":4,">":4,"<=":4,">=":4,
        "shl":5,"shr":5,"+":6,"-":6,"*":7,"/":7,"mod":7,"%":7,".":9}


def strip_comment(line):
    quote = None
    for pos,char in enumerate(line):
        if char in ("'", '"'):
            quote = None if quote == char else char if quote is None else quote
        elif char == ";" and quote is None:
            return line[:pos]
    return line


def arguments(text):
    result, start, depth, quote = [],0,0,None
    for index,char in enumerate(text):
        if char in ("'", '"'):
            quote = None if quote == char else char if quote is None else quote
        elif quote is None:
            if char == "(": depth += 1
            elif char == ")": depth -= 1
            elif char == "," and depth == 0:
                result.append(text[start:index].strip())
                start=index+1
    if text.strip():
        result.append(text[start:].strip())
    return result


class Expression:
    def __init__(self, symbols):
        self.symbols = symbols

    def evaluate(self, text):
        tokens=[]
        pos=0
        while pos < len(text.strip()):
            match=TOKEN.match(text,pos)
            if not match: raise ValueError("Unsupported expression: "+text[pos:])
            tokens.append(match[1])
            pos=match.end()
        index=0
        def parse(priority=0):
            nonlocal index
            if index >= len(tokens): raise ValueError("Missing operand: "+text)
            word=tokens[index]; index+=1
            lower=word.lower()
            if word=="(":
                value=parse()
                if tokens[index]!=")": raise ValueError(text)
                index+=1
            elif lower in ("-","+","not","~","low","high"):
                operand=parse(8)
                value={"-":lambda:-operand,"+":lambda:operand,
                       "not":lambda:~operand,"~":lambda:~operand,
                       "low":lambda:operand&255,"high":lambda:(operand>>8)&255}[lower]()
            elif word.startswith(("'",'"')):
                value=int.from_bytes(word[1:-1].encode("ascii"),"big")
            elif lower.startswith("0x"): value=int(word,16)
            elif word[0].isdigit():
                value=int(word[:-1],16) if lower.endswith("h") else int(word[:-1],2) if lower.endswith("b") else int(word)
            else:
                if lower not in self.symbols: raise KeyError(word)
                value=self.symbols[lower]
            while index<len(tokens) and tokens[index].lower() in PREC and PREC[tokens[index].lower()] > priority:
                operator=tokens[index].lower(); index+=1
                right=parse(PREC[operator])
                if operator in ("or","|"): value |= right
                elif operator in ("xor","^"): value ^= right
                elif operator in ("and","&"): value &= right
                elif operator in ("=","=="): value=int(value==right)
                elif operator in ("!=","<>"): value=int(value!=right)
                elif operator=="<": value=int(value<right)
                elif operator==">": value=int(value>right)
                elif operator=="<=": value=int(value<=right)
                elif operator==">=": value=int(value>=right)
                elif operator=="shl": value <<= right
                elif operator=="shr": value >>= right
                elif operator=="+": value += right
                elif operator=="-": value -= right
                elif operator=="*": value *= right
                elif operator=="/":
                    value=(abs(value)//abs(right))*(-1 if (value<0)!=(right<0) else 1)
                elif operator in ("mod","%"): value %= right
                elif operator==".":
                    value=value+right if value>=128 else (value-32)*8+right
            return value
        result=parse()
        if index!=len(tokens): raise ValueError("Unparsed expression: "+text)
        return result


class Frontend:
    def __init__(self, root, defines):
        self.root=Path(root).resolve()
        self.symbols={k.lower():v for k,v in defines.items()}
        for flag in ('CUSTOM_PWM_SETUP','CUSTOM_PWM_UPDATE','CUSTOM_PWM_PHASE','CUSTOM_FET_TOGGLING','CUSTOM_LED'):
            self.symbols[flag.lower()]=0
        self.macros={}
        self.literals={}
        self.output=["$NOMOD51"]
        self.output += [f"{key} EQU {value}" for key,value in defines.items()]
        self.counter=0
        self.segment="CSEG"
        self.address=0

    def evaluate(self,text):
        return Expression(self.symbols).evaluate(text.strip())

    def read(self,path):
        return [(strip_comment(line).strip(),str(path)+":"+str(index))
                for index,line in enumerate(path.read_text(encoding="utf-8").splitlines(),1)]

    def expand(self, lines, depth=0):
        if depth>50: raise ValueError("Macro/include recursion limit")
        conditions=[]
        index=0
        while index<len(lines):
            line,location=lines[index]; index+=1
            if not line: continue
            directive=line.lstrip("$").split(None,1)
            word=directive[0].lower()
            tail=directive[1] if len(directive)>1 else ""
            active=all(item["active"] for item in conditions)
            if word in ("if","ifdef","ifndef"):
                parent=active
                expression = tail
                logical_not = line.startswith('$') and tail.lower().startswith('not ')
                if logical_not:
                    expression = tail[4:]
                selected=(bool(self.evaluate(expression)) if word=="if" else (tail.lower() in self.symbols)) if parent else False
                if logical_not and parent:
                    selected = not selected
                if word=="ifndef": selected=not selected
                conditions.append({"active":parent and selected,"parent":parent,"taken":selected})
                continue
            if word in ("elseif","else"):
                condition=conditions[-1]
                selected=(not condition["taken"] and (word=="else" or bool(self.evaluate(tail)))) if condition["parent"] else False
                condition["active"]=condition["parent"] and selected
                condition["taken"] |= selected
                continue
            if word=="endif":
                conditions.pop()
                continue
            definition=re.match(r"^(\w+)\s+MACRO\b(.*)",line,re.I)
            if definition:
                body=[]; nesting=1
                while index<len(lines):
                    item=lines[index]; index+=1
                    if re.search(r"\bMACRO\b",item[0],re.I): nesting+=1
                    if re.match(r"^ENDM\b",item[0],re.I): nesting-=1
                    if not nesting: break
                    body.append(item)
                if active:
                    params=re.findall(r"[A-Za-z_]\w*",definition[2])
                    self.macros[definition[1].lower()]=(params,body)
                continue
            if not active: continue
            if line.lower().startswith('$set') or line.lower().startswith('$reset'):
                for name in re.findall(r'[A-Za-z_]\w*',tail):
                    self.symbols[name.lower()]=int(word=='set')
                continue
            if word=="include":
                name=tail.strip().strip("()").replace("\\","/")
                caller=Path(location.rsplit(":",1)[0])
                path=caller.parent/name
                if not path.is_file(): path=self.root/name
                if not path.is_file(): raise ValueError("Include missing: "+name)
                self.expand(self.read(path),depth+1)
                continue
            if word in ("end","nomod51","using"):
                if word=="end": self.output.append("END")
                continue
            if word=="exitm": return
            literal=re.match(r"^(\w+)\s+LIT\s+['\"](.*)['\"]$",line,re.I)
            if literal:
                self.literals[literal[1].lower()]=literal[2]
                continue
            if word in self.macros:
                params,body=self.macros[word]
                values=arguments(tail)
                if len(values)!=len(params): raise ValueError(f"Macro arity {location}: {line}")
                values=[str(self.evaluate(value[1:])) if value.startswith("%") else value for value in values]
                mapping=dict(zip((p.lower() for p in params),values))
                self.counter+=1
                for text,_ in body:
                    if text.lower().startswith("local "):
                        for local in re.findall(r"\w+",text[6:]):
                            mapping[local.lower()]=f"L_{self.counter}_{local}"
                expanded=[]
                for text,where in body:
                    if text.lower().startswith("local "): continue
                    text=re.sub(r"&([A-Za-z_]\w*)",lambda m:mapping.get(m[1].lower(),m[0]),text)
                    text=re.sub(r'"[^"]*"|\'[^\']*\'|[A-Za-z_]\w*',
                                lambda m:m[0] if m[0].startswith(("'",'"')) else mapping.get(m[0].lower(),m[0]),text)
                    expanded.append((text,where))
                self.expand(expanded,depth+1)
                continue
            if word in self.literals:
                line=self.literals[word]+(" "+tail if tail else "")
                word=self.literals[word].lower()
            definition=re.match(r"^(\w+)\s+(EQU|DATA|IDATA|BIT|SET)\s+(.+)$",line,re.I)
            if definition:
                name,kind,value=definition.groups()
                try:
                    numeric=self.evaluate(value)
                    self.symbols[name.lower()]=numeric
                    line=f"{name} {kind} {numeric & 65535}"
                except (KeyError,ValueError):
                    pass
                self.output.append(line)
                continue
            segment=re.match(r"^(CSEG|DSEG|ISEG|BSEG|XSEG)\s+AT\s+(.+)",line,re.I)
            if segment:
                self.segment=segment[1].upper()
                self.address=self.evaluate(segment[2])
            label=re.match(r"^(\w+):\s*(.*)$",line)
            if label and self.segment!="CSEG":
                self.symbols[label[1].lower()]=self.address
            storage=re.search(r"\bDS\s+(.+)$",line,re.I)
            if storage and self.segment!="CSEG": self.address += self.evaluate(storage[1])
            if "#" in line:
                left,immediate=line.split("#",1)
                try:
                    width=65535 if re.match(r"mov\s+dptr\s*,",left,re.I) else 255
                    # CJNE has a branch destination following the immediate.
                    args=arguments(immediate)
                    args[0]=str(self.evaluate(args[0]) & width)
                    line=left+"#"+", ".join(args)
                except (KeyError,ValueError):
                    pass
            self.output.append(line)
        if conditions: raise ValueError("Unbalanced conditional assembly")

    def compile(self,entry):
        self.expand(self.read(self.root/entry))
        # Some layouts override generic pin aliases before any instruction uses
        # them. Keil accepts EQU reassignment; ASEM requires one declaration.
        final = {}
        for index, line in enumerate(self.output):
            match = re.match(r"^(\w+)\s+EQU\b", line, re.I)
            if match:
                final[match[1].lower()] = index
        self.output = [line for index, line in enumerate(self.output)
                       if not (match := re.match(r"^(\w+)\s+EQU\b", line, re.I))
                       or final[match[1].lower()] == index]
        # ASEM-51 compares only 31 identifier characters. Preserve source names,
        # but use deterministic short identifiers in its generated input.
        def shorten(match):
            value=match[0]
            if value.startswith(('\"', "'")) or len(value)<=30: return value
            return 'S_'+hashlib.sha256(value.lower().encode()).hexdigest()[:24]
        return "\n".join(re.sub(r'\"[^\"]*\"|\'[^\']*\'|[A-Za-z_]\w*',shorten,line)
                         for line in self.output)+"\n"

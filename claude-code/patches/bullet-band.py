#!/usr/bin/env python3
"""Patch the Claude Code binary so the ⏺ bullet column carries the same pastel band as the
i-have-adhd marker lines (first line ⟶ green, last line ⟶ blue). Pairs with hooks/adhd-colors.sh.

Bun standalone layout (2.1.282): [chunks source+bytecode][module table][Offsets 32B]["\\n---- Bun! ----\\n"].
Same-length patch inside one chunk (bytes reclaimed from that chunk's licence comment), and the
chunk's bytecode pointer zeroed so Bun compiles the edited source. Then ad-hoc re-sign.

usage: bullet-band.py <binary> [--out <path>]   (in place by default, keeps <binary>.orig)
"""
import re, struct, subprocess, sys, shutil, os

OLD = (b'if(O[44]!==h)B=h&&e(Nc,{fromLeftEdge:!0,minWidth:2,children:e(n,{"aria-label":"claude:",'
       b'color:"text",children:Nr})}),O[44]=h,O[45]=B;')
NEW = (b'if(O[44]!==h||O[46]!==v)B=h&&e(Nc,{fromLeftEdge:!0,minWidth:2,flexDirection:"column",'
       b'justifyContent:"space-between",children:[e(n,{"aria-label":"claude:",color:"text",'
       b'backgroundColor:/^(?:\\x1b\\[[\\d;]*m)*\\u27F6/.test(v)?"#d6f5d6":void 0,children:[Nr," "]}),'
       b'/\\n(?:\\x1b\\[[\\d;]*m)*\\u27F6[^\\n]*\\s*$/.test(v)?e(n,{backgroundColor:"#d6e6ff",children:"  "}):null]}),'
       b'O[44]=h,O[45]=B;')
FOOT_OLD = [b'height:1,overflow:"hidden",children:[as,', b'height:1,overflow:"hidden",children:[$s,',
            b'height:1,overflow:"hidden",children:as})', b'height:1,overflow:"hidden",children:$s})']
# two blank rows under the "<mode> on" footer line: same-length edit, box grows, content stays 1 row
PATCHES = [(OLD, NEW)] + [(o, o.replace(b'height:1', b'height:3')) for o in FOOT_OLD]
# the statusline shows the permission mode; nothing on disk changes when it cycles, so the
# state-change handler drops it in ~/.claude/sessions/<pid>.mode (the statusline reads it first)
PATCHES.append((b'if(g!==f){let n=ql(g),a=ql(f);if(n!==a){let p=iPo({rule:"first-entry"',
                b'if(g!==f){Bun.write(process.env.HOME+"/.claude/sessions/"+process.pid+".mode",f).catch(()=>{});let n=ql(g),a=ql(f);if(n!==a){let p=iPo({rule:"first-entry"'))
# paint the two ⟶ lines in the completed-message render too, so a resumed transcript keeps the bands
# (the hook only runs live); a line the hook already painted starts with ESC, so it is skipped
PAINT = rb'((t,w,P=(l,c)=>c+l+"\xa0".repeat(Math.max(0,w-l.length))+"\x1b[0m")=>{let L=t.split("\n"),i=L.length-1;while(i>0&&!L[i].trim())i--;if(L[0][0]=="\u27F6")L[0]=P(L[0],"\x1b[48;2;214;245;214m");if(i>0&&L[i][0]=="\u27F6")L[i]=P(L[i],"\x1b[48;2;214;230;255m");return L.join("\n")})(v,(process.stdout.columns||80)-2)'
PATCHES.append((b'q=e(s,{flexDirection:"column",children:e(vi,{capProseWidth:!0,children:v})})',
                b'q=e(s,{flexDirection:"column",children:e(vi,{capProseWidth:!0,children:' + PAINT + b'})})'))
# the mode line itself ("⏵⏵ bypass permissions on (shift+tab to cycle)") moves to the statusline:
# never build it, and keep two blank rows when the footer has nothing else to show
PATCHES += [
    (b'let as=gr&&As?e(s,{flexShrink:0,children:e(sx,{mode:gr,', b'let as=!1&&As?e(s,{flexShrink:0,children:e(sx,{mode:gr,'),
    (b'let $s=zi&&gr?e(s,{flexShrink:0,children:e(sx,{mode:gr,children:Ts})', b'let $s=!1&&gr?e(s,{flexShrink:0,children:e(sx,{mode:gr,children:Ts})'),
    (b'!oi&&!Rs&&!es&&!Qt&&!Zt&&Io.length===0&&!wi&&An===0&&!Hs)return Bt?e(n,{children:" "}):null',
     b'!oi&&!Rs&&!es&&!Qt&&!Zt&&Io.length===0&&!wi&&An===0&&!Hs)return e(s,{height:2,children:e(n,{children:" "})})'),
    (b'!Es&&!as&&!Hn&&!oi&&!Rs&&!vr&&mi.length===0&&!Vr&&!ys)return Bt?e(n,{children:" "}):null',
     b'!Es&&!as&&!Hn&&!oi&&!Rs&&!vr&&mi.length===0&&!Vr&&!ys)return e(s,{height:2,children:e(n,{children:" "})})'),
    # the three hints that replace the footer (exit, pasting, expand-paste) are bare one-row Texts:
    # box them at the same height so the two blank rows never flicker away
    (b'Fr=e(n,{dimColor:!0,children:"Pasting\\u2026"},"pasting-message")',
     b'Fr=e(s,{height:3,children:e(n,{dimColor:!0,children:"Pasting\\u2026"})},"pasting-message")'),
    (b'Fr=e(n,{dimColor:!0,children:"paste again to expand"},"expand-paste-hint")',
     b'Fr=e(s,{height:3,children:e(n,{dimColor:!0,children:"paste again to expand"})},"expand-paste-hint")'),
    (b'Vn=r(n,{dimColor:!0,children:["Press ",Fr," again to"," ",Hn]},"exit-message")',
     b'Vn=e(s,{height:3,children:r(n,{dimColor:!0,children:["Press ",Fr," again to"," ",Hn]})},"exit-message")'),
]
TRAILER = b'\n---- Bun! ----\n'
RS = 52  # module record: name, contents, sourcemap?, bytecode (u32 pairs), 2 more u32, name again, flags

def main():
    src = sys.argv[1]
    out = sys.argv[sys.argv.index('--out') + 1] if '--out' in sys.argv else src
    b = bytearray(open(src, 'rb').read())
    todo = [(o, n) for o, n in PATCHES if not b.count(n)]
    if not todo:
        print('already patched'); return 0
    for o, _ in todo:
        assert b.count(o) == 1, f'anchor found {b.count(o)} times: {o[:60]}'
    t = b.rfind(TRAILER)
    byte_count, mod_off, mod_len = struct.unpack('<QII', b[t-32:t-16])
    G = t - 32 - byte_count
    chunks = {}
    for i in range(mod_len // RS):
        rec = G + mod_off + i * RS
        f = list(struct.unpack('<13I', b[rec:rec+RS]))
        s, e = G + f[2], G + f[2] + f[3]
        mine = [(o, n) for o, n in todo if s <= b.find(o) < e]
        if mine:
            chunks[i] = (rec, f, s, e, mine)
    assert sum(len(c[4]) for c in chunks.values()) == len(todo), 'patch outside any chunk'
    for i, (rec, f, s, e, mine) in chunks.items():
        chunk = bytes(b[s:e])
        assert chunk.startswith(b'// @bun @bytecode\n'), chunk[:40]
        delta = sum(len(n) - len(o) for o, n in mine)
        hdr_end = chunk.find(b'// Version:')
        comment = chunk[18:hdr_end]
        assert delta < len(comment) - 4, 'not enough comment bytes to reclaim'
        comment2 = comment[:len(comment) - 1 - delta] + b'\n' if delta >= 0 else comment[:-1] + b' ' * -delta + b'\n'
        chunk2 = chunk[:18] + comment2 + chunk[hdr_end:]
        for o, n in mine:
            chunk2 = chunk2.replace(o, n)
        assert len(chunk2) == len(chunk), (len(chunk2), len(chunk))
        b[s:e] = chunk2
        f[6] = f[7] = 0  # drop bytecode cache for this chunk
        b[rec:rec+RS] = struct.pack('<13I', *f)
        print(f'chunk {i}: {len(mine)} patch(es), reclaimed {delta} bytes from header comment')
    if out == src and not os.path.exists(src + '.orig'):
        shutil.copy2(src, src + '.orig')
    tmp = out + '.new'  # never truncate in place: a running claude has the file mapped
    open(tmp, 'wb').write(b)
    os.chmod(tmp, 0o755)
    subprocess.run(['codesign', '-s', '-', '-f', '--preserve-metadata=entitlements,flags', tmp], check=True)
    os.replace(tmp, out)
    print(f'signed: {out}')

if __name__ == '__main__':
    sys.exit(main())

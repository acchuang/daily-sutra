#!/usr/bin/env python3
"""Fetch + segment the Diamond Sutra (Kumārajīva Chinese + Gemmell 1912 English PD)
into verses.json for the menu bar app. No sutra text is authored here — only
mechanical extraction from verified PD sources."""
import json, re, sys, urllib.request

CN_URL = "https://zh.wikisource.org/w/index.php?title=%E9%91%BC%E6%91%A9%E7%BE%85%E4%BB%80%E8%AD%AF%E6%9C%AC%E9%87%91%E5%89%9B%E8%88%AC%E8%8B%A5%E6%B3%A2%E7%BE%85%E8%9C%9C%E7%B6%93&action=raw"
CN_URL = "https://zh.wikisource.org/w/index.php?title=%E9%87%91%E5%89%9B%E8%88%AC%E8%8B%A5%E6%B3%A2%E7%BE%85%E8%9C%9C%E7%B6%93_(%E9%B3%A9%E6%91%A9%E7%BE%85%E4%BB%80)&action=raw"
EN_URL = "https://www.gutenberg.org/cache/epub/64623/pg64623.txt"

HAN = {"一":1,"二":2,"三":3,"四":4,"五":5,"六":6,"七":7,"八":8,"九":9,"十":10,
       "十一":11,"十二":12,"十三":13,"十四":14,"十五":15,"十六":16,"十七":17,"十八":18,
       "十九":19,"二十":20,"二十一":21,"二十二":22,"二十三":23,"二十四":24,"二十五":25,
       "二十六":26,"二十七":27,"二十八":28,"二十九":29,"三十":30,"三十一":31,"三十二":32}

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "diamond-sutra-bar/1.0 (build script)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode("utf-8")

def segment_chinese(raw):
    lines = raw.splitlines()
    # keep only the region from first ==== header to end-of-sutra (before external links)
    first = next(i for i,l in enumerate(lines) if l.startswith("===="))
    # the sutra body ends before the first `^==` (wikitext section, e.g. ==外部链接==) after the last ==== header,
    # or a {{Footer}} / {{PD-old}} line
    last_h = max(i for i,l in enumerate(lines) if l.startswith("===="))
    end = len(lines)
    for i in range(last_h+1, len(lines)):
        if lines[i].startswith("==") and not lines[i].startswith("==="):
            end = i; break
        if lines[i].startswith("{{Footer}}") or lines[i].startswith("{{PD-old}}"):
            end = i; break
    body = lines[first:end]
    sections = {}
    cur_num = None
    cur_title = None
    cur_buf = []
    pat = re.compile(r"^====(.+?)分第([一二三四五六七八九十]+)『(.+?)』====$")
    for l in body:
        m = pat.match(l)
        if m:
            if cur_num is not None:
                sections[cur_num] = (cur_title, "\n".join(cur_buf).strip())
            cur_title = m.group(1)
            cur_num = HAN[m.group(2)]
            cur_buf = []
        else:
            cur_buf.append(l)
    if cur_num is not None:
        sections[cur_num] = (cur_title, "\n".join(cur_buf).strip())
    return sections

def segment_english(raw):
    lines = raw.splitlines()
    start = next(i for i,l in enumerate(lines) if l.strip() == "[Chapter 1]")
    end_marker = "*** END OF THE PROJECT GUTENBERG EBOOK"
    end = next(i for i,l in enumerate(lines) if l.startswith(end_marker))
    body = lines[start:end]
    sections = {}
    cur_num = None
    cur_buf = []
    pat = re.compile(r"^\[Chapter (\d+)(?:\s+and\s+(\d+))?\]$")
    # chapter 4 begins with this paragraph (per librarian note)
    ch4_split = "Moreover, Subhuti, an enlightened disciple ought to act spontaneously"
    for l in body:
        m = pat.match(l.strip())
        if m:
            if cur_num is not None:
                sections[cur_num] = "\n".join(cur_buf).strip()
            if m.group(2):
                # merged [Chapter 3 and 4] — emit as 3, will split for 4 later
                cur_num = int(m.group(1))
            else:
                cur_num = int(m.group(1))
            cur_buf = []
        else:
            cur_buf.append(l)
    if cur_num is not None:
        sections[cur_num] = "\n".join(cur_buf).strip()
    # split merged chapter 3 (which actually holds 3+4) — find ch4_split
    if 3 in sections and 4 not in sections and ch4_split in sections[3]:
        idx = sections[3].index(ch4_split)
        sections[4] = sections[3][idx:].strip()
        sections[3] = sections[3][:idx].strip()
    # strip footnote blocks: cut at first run of blank line then "  [N]" footnote
    def clean(t):
        # remove inline [N] reference markers
        t = re.sub(r"\[\d+\]", "", t)
        # collapse whitespace
        t = re.sub(r"\n{3,}", "\n\n", t).strip()
        return t
    return {k: clean(v) for k,v in sections.items()}

def main():
    out_path = sys.argv[1]
    # preserve authored editorial fields (verseEn, meaning) from existing JSON
    existing = {}
    existing_heart = []
    try:
        with open(out_path, encoding="utf-8") as f:
            for s in json.load(f):
                if s.get("sutra") == "heart":
                    existing_heart.append(s)
                else:
                    existing[(s.get("sutra", "diamond"), s["index"])] = s
    except Exception:
        pass

    print("fetching chinese...", file=sys.stderr)
    cn = fetch(CN_URL)
    print("fetching english...", file=sys.stderr)
    en = fetch(EN_URL)
    cn_sec = segment_chinese(cn)
    en_sec = segment_english(en)
    print(f"cn sections: {sorted(cn_sec.keys())}", file=sys.stderr)
    print(f"en sections: {sorted(en_sec.keys())}", file=sys.stderr)
    out = []
    for n in range(1, 33):
        title, zh = cn_sec.get(n, ("?", ""))
        en_text = en_sec.get(n, "")
        prev = existing.get(("diamond", n), {})
        out.append({
            "index": n, "sutra": "diamond",
            "titleZh": f"{title}分第{[k for k,v in HAN.items() if v==n][0]}",
            "titleEn": f"Chapter {n}",
            "zh": zh,
            "en": en_text,
            "verseEn": prev.get("verseEn", ""),
            "verseZh": prev.get("verseZh", ""),
            "explEn": prev.get("explEn", ""),
            "explZh": prev.get("explZh", ""),
            "meaning": prev.get("meaning", ""),
            "meaningZh": prev.get("meaningZh", ""),
            "blessing": prev.get("blessing", ""),
            "blessingZh": prev.get("blessingZh", ""),
        })
    # Heart Sutra is fully authored (Xuanzang canonical text, PD) — keep as-is.
    out.extend(existing_heart)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    print(f"wrote {len(out)} sections to {out_path} (diamond {len(out)-len(existing_heart)} + heart {len(existing_heart)})", file=sys.stderr)

if __name__ == "__main__":
    main()
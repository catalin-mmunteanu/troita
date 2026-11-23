"""Extract the New Testament from the 1988 Synodal Bible PDF into JSON.

The PDF stores Romanian letters in a second font subset: inside those spans
every ASCII glyph is shifted by 29 (Q=n, ]=z, V=s, \x03=space...) and
ú/ù/Ġ/ğ stand for ș/Ș/ț/Ț. Verse text is 13.5pt regular, chapter summaries
13.5pt bold, "CAP. n" 13.1pt bold, cross references 9.8pt, page header 11.7pt.
"""
import json, re, sys
import pymupdf

SPECIAL = set("ăúĠùğĂ")
MAP = {"ú": "ș", "ù": "Ș", "Ġ": "ț", "ğ": "Ț"}

def decode(text):
    if not (set(text) & SPECIAL):
        return text
    out = []
    for ch in text:
        if ch in MAP: out.append(MAP[ch])
        elif ch != " " and ord(ch) < 0x60: out.append(chr(ord(ch) + 29))
        else: out.append(ch)
    return "".join(out)

BOOKS = [  # heading prefix as printed -> (id, name)
    ("SFÂNTA EVANGHELIE DUPĂ MATEI", "Mt", "Matei"),
    ("SFÂNTA EVANGHELIE DUPĂ MARCU", "Mc", "Marcu"),
    ("SFÂNTA EVANGHELIE DUPĂ LUCA", "Lc", "Luca"),
    ("SFÂNTA EVANGHELIE DUPĂ IOAN", "In", "Ioan"),
    ("FAPTELE SFINȚILOR APOSTOLI", "Fa", "Faptele Apostolilor"),
    ("EPISTOLA CĂTRE ROMANI", "Rom", "Romani"),
    ("ÎNTÂIA EPISTOLĂ CĂTRE CORINTENI", "1Co", "1 Corinteni"),
    ("A DOUA EPISTOLĂ CĂTRE CORINTENI", "2Co", "2 Corinteni"),
    ("EPISTOLA CĂTRE GALATENI", "Gal", "Galateni"),
    ("EPISTOLA CĂTRE EFESENI", "Ef", "Efeseni"),
    ("EPISTOLA CĂTRE FILIPENI", "Flp", "Filipeni"),
    ("EPISTOLA CĂTRE COLOSENI", "Col", "Coloseni"),
    ("EPISTOLA ÎNTÂIA CĂTRE TESALONICENI", "1Tes", "1 Tesaloniceni"),
    ("EPISTOLA A DOUA CĂTRE TESALONICENI", "2Tes", "2 Tesaloniceni"),
    ("EPISTOLA ÎNTÂIA CĂTRE TIMOTEI", "1Tim", "1 Timotei"),
    ("EPISTOLA A DOUA CĂTRE TIMOTEI", "2Tim", "2 Timotei"),
    ("EPISTOLA CĂTRE TIT", "Tit", "Tit"),
    ("EPISTOLA CĂTRE FILIMON", "Flm", "Filimon"),
    ("EPISTOLA CĂTRE EVREI", "Evr", "Evrei"),
    ("EPISTOLA SOBORNICEASCĂ A SFÂNTULUI APOSTOL IACOV", "Iac", "Iacov"),
    ("ÎNTÂIA EPISTOLĂ SOBORNICEASCĂ A SFÂNTULUI APOSTOL PETRU", "1Pt", "1 Petru"),
    ("A DOUA EPISTOLĂ SOBORNICEASCĂ A SFÂNTULUI APOSTOL PETRU", "2Pt", "2 Petru"),
    ("ÎNTÂIA EPISTOLĂ SOBORNICEASCĂ A SFÂNTULUI APOSTOL IOAN", "1In", "1 Ioan"),
    ("A DOUA EPISTOLĂ SOBORNICEASCĂ A SFÂNTULUI APOSTOL IOAN", "2In", "2 Ioan"),
    ("A TREIA EPISTOLĂ SOBORNICEASCĂ A SFÂNTULUI APOSTOL IOAN", "3In", "3 Ioan"),
    ("EPISTOLA SOBORNICEASCĂ A SFÂNTULUI APOSTOL IUDA", "Iuda", "Iuda"),
    ("APOCALIPSA SFÂNTULUI IOAN", "Ap", "Apocalipsa"),
]

def lines(doc, start):
    for i in range(start, doc.page_count):
        for b in doc[i].get_text("dict")["blocks"]:
            for l in b.get("lines", []):
                sp = l["spans"]
                if not sp: continue
                text = "".join(decode(s["text"]) for s in sp)
                size = max(round(s["size"], 1) for s in sp)
                bold = any(s["flags"] & 16 for s in sp)
                yield i, size, bold, text

def main(pdf, out):
    doc = pymupdf.open(pdf)
    books, book, chap, verse = [], None, None, None
    heading = ""
    for page, size, bold, text in lines(doc, 1167):
        t = text.strip()
        if not t or size < 10.5 or t.startswith("pag. "):
            continue  # cross references, page headers
        if bold and size > 14:  # book heading, may span lines
            if book and book["id"] == "Ap" and len(book["chapters"]) == 22:
                break  # the deuterocanonical books follow; the NT is done
            heading = (heading + " " + t).strip()
            hit = [b for b in BOOKS if " ".join(heading.split()).startswith(b[0]) or b[0].startswith(" ".join(heading.split()))]
            exact = [b for b in BOOKS if " ".join(heading.split()).startswith(b[0])]
            if exact:
                if book and book["id"] == exact[-1][1]: continue
                book = {"id": exact[-1][1], "name": exact[-1][2], "chapters": []}
                books.append(book); chap = verse = None
            if not hit: heading = ""
            continue
        heading = ""
        if book is None: continue
        m = re.match(r"CAP\.\s*(\d+)", t)
        if bold and m:
            chap = {"n": int(m.group(1)), "verses": []}
            book["chapters"].append(chap); verse = None
            continue
        if bold:  # chapter summary
            continue
        if chap is None and re.match(r"1\.(\s|$)", t):
            chap = {"n": 1, "verses": []}  # one-chapter books without "CAP. 1"
            book["chapters"].append(chap)
        if chap is None: continue
        m = re.match(r"(\d+)\.(?:\s+(.*)|$)", t)
        if m and int(m.group(1)) == (verse["n"] + 1 if verse else 1):
            verse = {"n": int(m.group(1)), "t": m.group(2) or ""}
            chap["verses"].append(verse)
        elif verse is not None:
            # join wrapped lines; a trailing hyphen inside a word is a line break
            if verse["t"].endswith("-") and not verse["t"].endswith(" -"):
                verse["t"] = verse["t"] + t
            else:
                verse["t"] = verse["t"].rstrip() + " " + t
    for b in books:
        for c in b["chapters"]:
            for v in c["verses"]:
                v["t"] = re.sub(r"\s+", " ", v["t"]).strip()
                v["t"] = re.sub(r" ([;:?!])", r"\1", v["t"])  # "zis :" -> "zis:"
                v["t"] = v["t"].replace("©", "«")  # one mis-encoded quote (Iac 2, 23)
    json.dump(books, open(out, "w", encoding="utf-8"), ensure_ascii=False, indent=0)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

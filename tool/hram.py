# -*- coding: utf-8 -*-
"""Hram (patron-saint) inference for Romanian Orthodox church names.

OSM almost never tags `church:patron`, so the hram has to be parsed out of the
name: "Biserica Sfântul Nicolae Vlădica" -> patron "Sfântul Nicolae", feast 12-06.

Fixed feasts are 'MM-DD'. Feasts tied to Pascha are 'movable:<key>' and are
resolved on-device against the Orthodox (Julian-computus) Pascha date.
"""
import re
import unicodedata

# key -> (canonical patron label, feast)
FEASTS = [
    # --- Great feasts / Theotokos ---
    ("adormirea maicii domnului",        "Adormirea Maicii Domnului",              "08-15"),
    ("nasterea maicii domnului",         "Nașterea Maicii Domnului",               "09-08"),
    ("intrarea in biserica",             "Intrarea în Biserică a Maicii Domnului", "11-21"),
    ("buna vestire",                     "Buna Vestire",                           "03-25"),
    ("acoperamantul maicii domnului",    "Acoperământul Maicii Domnului",          "10-01"),
    ("nasterea domnului",                "Nașterea Domnului",                      "12-25"),
    ("botezul domnului",                 "Botezul Domnului",                       "01-06"),
    ("intampinarea domnului",            "Întâmpinarea Domnului",                  "02-02"),
    ("schimbarea la fata",               "Schimbarea la Față",                     "08-06"),
    ("inaltarea sfintei cruci",          "Înălțarea Sfintei Cruci",                "09-14"),
    ("inaltarea domnului",               "Înălțarea Domnului",           "movable:ascension"),
    ("sfanta treime",                    "Sfânta Treime",                "movable:pentecost_monday"),
    ("pogorarea sfantului duh",          "Pogorârea Sfântului Duh",      "movable:pentecost"),
    ("izvorul tamaduirii",               "Izvorul Tămăduirii",           "movable:bright_friday"),
    ("intrarea domnului in ierusalim",   "Intrarea Domnului în Ierusalim", "movable:palm_sunday"),
    ("invierea domnului",                "Învierea Domnului",            "movable:pascha"),
    ("duminica tuturor sfintilor",       "Duminica Tuturor Sfinților",   "movable:all_saints"),
    # --- Saints, most frequent hramuri in Muntenia first ---
    ("dimitrie cel nou",                 "Sfântul Cuvios Dimitrie cel Nou",        "10-27"),
    ("nicolae",                          "Sfântul Ierarh Nicolae",                 "12-06"),
    ("gheorghe",                         "Sfântul Mare Mucenic Gheorghe",          "04-23"),
    ("dumitru",                          "Sfântul Mare Mucenic Dimitrie",          "10-26"),
    ("dimitrie izvoratorul de mir",      "Sfântul Mare Mucenic Dimitrie",          "10-26"),
    ("petru si pavel",                   "Sfinții Apostoli Petru și Pavel",        "06-29"),
    ("constantin si elena",              "Sfinții Împărați Constantin și Elena",   "05-21"),
    ("mihail si gavriil",                "Sfinții Arhangheli Mihail și Gavriil",   "11-08"),
    ("voievozi",                         "Sfinții Arhangheli Mihail și Gavriil",   "11-08"),
    ("parascheva",                       "Sfânta Cuvioasă Parascheva",             "10-14"),
    ("cuvioasa parascheva",              "Sfânta Cuvioasă Parascheva",             "10-14"),
    ("sfanta vineri",                    "Sfânta Cuvioasă Parascheva",             "10-14"),
    ("trei ierarhi",                     "Sfinții Trei Ierarhi",                   "01-30"),
    ("spiridon",                         "Sfântul Ierarh Spiridon",                "12-12"),
    ("ilie",                             "Sfântul Prooroc Ilie Tesviteanul",       "07-20"),
    ("elefterie",                        "Sfântul Mucenic Elefterie",              "12-15"),
    ("pantelimon",                       "Sfântul Mare Mucenic Pantelimon",        "07-27"),
    ("mina",                             "Sfântul Mare Mucenic Mina",              "11-11"),
    ("haralambie",                       "Sfântul Sfințit Mucenic Haralambie",     "02-10"),
    ("stefan cel mare",                  "Sfântul Voievod Ștefan cel Mare",        "07-02"),
    ("stefan",                           "Sfântul Arhidiacon Ștefan",              "12-27"),
    ("andrei",                           "Sfântul Apostol Andrei",                 "11-30"),
    ("vasile",                           "Sfântul Ierarh Vasile cel Mare",         "01-01"),
    ("antonie cel mare",                 "Sfântul Cuvios Antonie cel Mare",        "01-17"),
    ("silvestru",                        "Sfântul Ierarh Silvestru",               "01-02"),
    ("ecaterina",                        "Sfânta Mare Muceniță Ecaterina",         "11-25"),
    ("varvara",                          "Sfânta Mare Muceniță Varvara",           "12-04"),
    ("calinic",                          "Sfântul Ierarh Calinic de la Cernica",   "04-11"),
    ("visarion",                         "Sfântul Ierarh Visarion",                "06-06"),
    ("ioan gura de aur",                 "Sfântul Ierarh Ioan Gură de Aur",        "11-13"),
    ("taierea capului sfantului ioan",   "Tăierea Capului Sfântului Ioan Botezătorul", "08-29"),
    ("nasterea sfantului ioan",          "Nașterea Sfântului Ioan Botezătorul",    "06-24"),
    ("ioan botezatorul",                 "Soborul Sfântului Ioan Botezătorul",     "01-07"),
    ("ioan cel nou",                     "Sfântul Ioan cel Nou de la Suceava",     "06-02"),
    ("ioan",                             "Soborul Sfântului Ioan Botezătorul",     "01-07"),
    ("apostol toma",                     "Sfântul Apostol Toma",                   "10-06"),
    ("filip",                            "Sfântul Apostol Filip",                  "11-14"),
    ("grigorie",                         "Sfântul Ierarh Grigorie Teologul",       "01-25"),
    ("teodor tiron",                     "Sfântul Mucenic Teodor Tiron",  "movable:theodore_saturday"),
    ("cuviosul siluan",                  "Sfântul Cuvios Siluan Athonitul",        "09-24"),
    ("maria magdalena",                  "Sfânta Maria Magdalena",                 "07-22"),
    ("anton",                            "Sfântul Cuvios Antonie cel Mare",        "01-17"),
    ("lazar",                            "Sfântul Lazăr",                 "movable:lazarus_saturday"),
]

_STRIP = re.compile(
    r"^(sfanta|sfantul|sfintii|sfintele|sf\.?|biserica|manastirea|manastire|"
    r"catedrala|paraclisul|schitul|capela|troita)\s+",
    re.IGNORECASE,
)


def _fold(s: str) -> str:
    """Lowercase, strip Romanian diacritics, collapse whitespace."""
    s = s.replace("ș", "s").replace("ş", "s").replace("ț", "t").replace("ţ", "t")
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-zA-Z0-9\s]", " ", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def infer(name: str, tag_patron: str | None = None) -> tuple[str | None, str | None]:
    """Return (patron_label, feast) inferred from an explicit tag or the name."""
    for candidate in (tag_patron, name):
        if not candidate:
            continue
        folded = _fold(candidate)
        # Longest key first so "dimitrie cel nou" wins over "dumitru",
        # "nasterea maicii domnului" over "nasterea domnului".
        for key, label, feast in sorted(FEASTS, key=lambda f: -len(f[0])):
            if key in folded:
                return label, feast
    return None, None


def clean_name(name: str) -> str:
    return re.sub(r"\s+", " ", name).strip()


def guess_kind(tags: dict) -> str:
    if tags.get("historic") in ("wayside_cross", "wayside_shrine"):
        return "wayside_cross"
    if tags.get("building") == "cathedral" or "catedrala" in _fold(tags.get("name", "")):
        return "cathedral"
    if tags.get("amenity") == "monastery" or tags.get("building") == "monastery":
        return "monastery"
    folded = _fold(tags.get("name", ""))
    if folded.startswith("manastirea") or folded.startswith("manastire"):
        return "monastery"
    if folded.startswith("schitul"):
        return "monastery"
    if tags.get("building") == "chapel" or folded.startswith("capela") or folded.startswith("paraclis"):
        return "chapel"
    return "church"

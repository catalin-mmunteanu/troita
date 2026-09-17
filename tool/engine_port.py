# -*- coding: utf-8 -*-
"""Python mirror of lib/core/liturgical/ — used only to verify the Dart engine
against published calendars. Keep the two in step; if they diverge, the Dart
one is the product and this one is wrong."""
from datetime import date, timedelta

RANK_WEIGHT = {'praznic': 3, 'cruce_rosie': 2, 'cruce_albastra': 1, 'simplu': 0}
ORDER = ['none', 'dairy', 'fish', 'wineOil', 'fast', 'strict']


def looser(a, b):
    return a if ORDER.index(a) <= ORDER.index(b) else b


def stricter(a, b):
    return a if ORDER.index(a) >= ORDER.index(b) else b


def pascha(y):
    a, b, c = y % 4, y % 7, y % 19
    d = (19 * c + 15) % 30
    e = (2 * a + 4 * b - d + 34) % 7
    m = (d + e + 114) // 31
    dd = ((d + e + 114) % 31) + 1
    return date(y, m, dd) + timedelta(days=13 if y < 2100 else 14)


def great_fasts(y):
    p = pascha(y)
    out = [('postulMare', p - timedelta(days=48), p - timedelta(days=1)),
           ('postulAdormirii', date(y, 8, 1), date(y, 8, 14)),
           ('postulCraciunului', date(y, 11, 15), date(y, 12, 24))]
    start, end = p + timedelta(days=57), date(y, 6, 28)
    if start <= end:
        out.append(('postulApostolilor', start, end))
    return sorted(out, key=lambda t: t[1])


def harti(y):
    p = pascha(y)
    return [(date(y, 12, 25), date(y + 1, 1, 4)),
            (p - timedelta(days=69), p - timedelta(days=64)),
            (p, p + timedelta(days=6)),
            (p + timedelta(days=50), p + timedelta(days=56))]


def branza(y):
    p = pascha(y)
    return (p - timedelta(days=55), p - timedelta(days=49))


def fast_level_for(year, month, day, rank='simplu'):
    d = date(year, month, day)
    p = pascha(d.year)
    weekend = d.weekday() >= 5

    for yy in (d.year - 1, d.year):
        for s, e in harti(yy):
            if s <= d <= e:
                return _fixed(d, 'none')
    bs, be = branza(d.year)
    if bs <= d <= be:
        return _fixed(d, 'dairy')

    level = None
    for kind, s, e in great_fasts(d.year):
        if not (s <= d <= e):
            continue
        if kind == 'postulMare':
            if d == p - timedelta(days=48) or d == p - timedelta(days=2):
                level = 'strict'
            elif (d.month, d.day) == (3, 25) or d == p - timedelta(days=7):
                level = 'fish'
            elif d == p - timedelta(days=8):
                level = 'wineOil'
            else:
                level = 'wineOil' if weekend else 'fast'
        elif kind == 'postulAdormirii':
            if (d.month, d.day) == (8, 6):
                level = 'fish'
            elif weekend or d.weekday() in (1, 3):
                level = 'wineOil'
            else:
                level = 'fast'
        elif kind == 'postulApostolilor':
            if d.weekday() in (2, 4):
                level = 'wineOil' if RANK_WEIGHT[rank] >= 2 else 'fast'
            elif d.weekday() == 0:
                level = 'wineOil'
            else:
                level = 'fish'
        elif kind == 'postulCraciunului':
            if (d.month, d.day) == (12, 24):
                level = 'strict'
            elif (d.month, d.day) in ((11, 21), (11, 30), (12, 6)):
                level = 'fish'
            elif d.month == 11 or d.day <= 20:
                level = 'fish' if (weekend or d.weekday() in (1, 3)) else 'wineOil'
            else:
                level = 'wineOil' if weekend else 'fast'
        break

    if level is None:
        if d.weekday() not in (2, 4):
            level = 'none'
        else:
            level = {'praznic': 'fish', 'cruce_rosie': 'wineOil'}.get(rank, 'fast')

    return _fixed(d, level)


def _fixed(d, level):
    if (d.month, d.day) == (1, 5):
        return stricter(level, 'strict')
    if (d.month, d.day) in ((8, 29), (9, 14)):
        return stricter(level, 'fast')
    return level


def glas_for(d):
    anchor = pascha(d.year) + timedelta(days=7)
    if d < anchor:
        anchor = pascha(d.year - 1) + timedelta(days=7)
    weeks = (d - anchor).days // 7
    return (weeks % 8) + 1 if weeks >= 0 else None


def voscreasna_for(d):
    anchor = pascha(d.year) + timedelta(days=7)
    if d < anchor:
        anchor = pascha(d.year - 1) + timedelta(days=7)
    weeks = (d - anchor).days // 7
    return ((weeks + 4) % 11) + 1 if weeks >= 0 else None

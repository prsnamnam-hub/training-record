#!/usr/bin/env python3
"""
ASW Training Record — Historical Data Migration builder.

Reads the source Excel in Training/ and writes SQL chunk files that call
public.import_training_rows(...) with data_source = 'Historical Excel'.
The same import function is used by the web Import Center, so historical and
future imports share one set of validation + duplicate-protection rules.

Output (gitignored — contains employee personal data):
  database/seed/historical_01.sql ...   one chunk per ~600 rows
  database/seed/historical_rows.json    all rows (for testing)

Usage:  python3 scripts/build_historical_seed.py [path/to/file.xlsx]
"""
import json
import math
import sys
from collections import Counter
from datetime import datetime, date, timedelta
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_XLSX = ROOT / "รายการหลักสูตรอบรม_update 2569 (EmpInfo_Date).xlsx"
OUT = ROOT / "database" / "seed"
CHUNK = 1500
# employee master fields are sent once per employee per chunk (keeps each chunk small)
EMP_STATIC = ["title_th", "first_name_th", "last_name_th", "nickname", "legacy_title", "legacy_first_name",
              "legacy_last_name", "legacy_nickname", "company_name", "area_code", "area_name", "work_location",
              "level_group_name", "position_name", "job_level", "job_title", "job_group", "employment_status",
              "hire_date", "probation_date", "termination_date", "name_check_result"]
EXCEL_NA = -2146826246  # value openpyxl returns for a cached #N/A


def clean(v):
    if v is None:
        return None
    if isinstance(v, (int, float)) and v == EXCEL_NA:
        return None
    if isinstance(v, str):
        v = " ".join(v.split())
        return v or None
    return v


def as_text(v):
    v = clean(v)
    if v is None:
        return None
    if isinstance(v, float) and v.is_integer():
        v = int(v)
    return str(v)


def as_date(v):
    v = clean(v)
    if v is None:
        return None
    if isinstance(v, datetime):
        return v.date().isoformat()
    if isinstance(v, date):
        return v.isoformat()
    if isinstance(v, (int, float)) and 20000 < v < 80000:  # Excel serial date
        return (date(1899, 12, 30) + timedelta(days=int(v))).isoformat()
    return None


def be_to_ce(v):
    """'2566' / 2566 / '2566-67' -> 2023"""
    v = as_text(v)
    if not v:
        return None
    try:
        return int(v[:4]) - 543
    except ValueError:
        return None


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_XLSX
    wb = openpyxl.load_workbook(src, data_only=True, read_only=True)
    tr = wb["Training Record"]
    tc = wb["Training Courses"]

    header = [c for c in next(tr.iter_rows(min_row=1, max_row=1, values_only=True))]
    col = {h: i for i, h in enumerate(header) if h}
    # the sheet has two "ชื่อเล่น" columns; the second (HR report) is at index Y
    raw_rows = [r for r in tr.iter_rows(min_row=2, values_only=True) if any(x is not None for x in r)]

    def g(r, letter_idx):
        return r[letter_idx] if letter_idx < len(r) else None

    # column indexes by Excel letter (A=0)
    L = {k: i for i, k in enumerate(
        ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
         "U", "V", "W", "X", "Y", "Z", "AA", "AB", "AC", "AD", "AE", "AF", "AG", "AH", "AI", "AJ", "AK", "AL",
         "AM", "AN", "AO"])}
    assert header[L["O"]] == "ชื่อหลักสูตร" and header[L["AO"]] == "Course ID", "unexpected sheet layout"

    # department code -> most frequent name (6 codes carry more than one spelling)
    names_by_code = {}
    for r in raw_rows:
        code, name = as_text(g(r, L["K"])), as_text(g(r, L["L"]))
        if code and name:
            names_by_code.setdefault(code, Counter())[name] += 1
    dept_name = {c: cnt.most_common(1)[0][0] for c, cnt in names_by_code.items()}

    rows = []
    for idx, r in enumerate(raw_rows, start=2):
        emp_code = as_text(g(r, L["U"]))
        in_hr = emp_code is not None
        if not emp_code:
            b = as_text(g(r, L["B"]))
            emp_code = b.zfill(5) if b and b.isdigit() else b
        start = as_date(g(r, L["P"]))
        year = int(start[:4]) if start else be_to_ce(g(r, L["R"]))
        dcode = as_text(g(r, L["K"]))
        job_level = clean(g(r, L["G"]))
        rows.append({
            "row_no": idx,
            "employee_code": emp_code,
            "title_th": as_text(g(r, L["V"])), "first_name_th": as_text(g(r, L["W"])),
            "last_name_th": as_text(g(r, L["X"])), "nickname": as_text(g(r, L["Y"])),
            "legacy_title": as_text(g(r, L["C"])), "legacy_first_name": as_text(g(r, L["D"])),
            "legacy_last_name": as_text(g(r, L["E"])), "legacy_nickname": as_text(g(r, L["F"])),
            "company_code": as_text(g(r, L["Z"])), "company_name": as_text(g(r, L["AA"])),
            "area_code": as_text(g(r, L["AB"])), "area_name": as_text(g(r, L["AC"])),
            "work_location": as_text(g(r, L["AE"])),
            "business_group": as_text(g(r, L["J"])),
            "department_code": dcode,
            "department_name": dept_name.get(dcode) if dcode else as_text(g(r, L["L"])),
            "level_group_code": as_text(g(r, L["AF"])), "level_group_name": as_text(g(r, L["AG"])),
            "position_code": as_text(g(r, L["AH"])), "position_name": as_text(g(r, L["AI"])),
            "job_level": int(job_level) if isinstance(job_level, (int, float)) else None,
            "job_title": as_text(g(r, L["H"])) if isinstance(clean(g(r, L["H"])), str) else None,
            "job_group": as_text(g(r, L["I"])) if isinstance(clean(g(r, L["I"])), str) else None,
            "employment_status": as_text(g(r, L["N"])),
            "hire_date": as_date(g(r, L["AJ"])), "probation_date": as_date(g(r, L["AK"])),
            "termination_date": as_date(g(r, L["AL"])) or as_date(g(r, L["M"])),
            "name_check_result": as_text(g(r, L["AM"])),
            "in_hr_master": in_hr,
            "course_name": as_text(g(r, L["O"])),
            "start_date": start,
            "end_date": as_date(g(r, L["AN"])),
            "fiscal_year": year,
            "legacy_month_text": as_text(g(r, L["Q"])),
            "training_type": as_text(g(r, L["S"])),
            "legacy_course_id": int(g(r, L["AO"])),
            "legacy_value": clean(g(r, L["T"])),
        })

    # sessions in "Training Courses" with no participants -> session-only rows
    used = {r["legacy_course_id"] for r in rows}
    tc_rows = [r for r in tc.iter_rows(min_row=2, values_only=True) if len(r) > 20 and r[20] is not None]
    for r in tc_rows:
        cid = int(r[20])
        if cid in used:
            continue
        start = as_date(r[15])
        rows.append({
            "row_no": None, "employee_code": None,
            "course_name": as_text(r[14]), "start_date": start, "end_date": as_date(r[19]),
            "fiscal_year": int(start[:4]) if start else be_to_ce(r[17]),
            "legacy_month_text": as_text(r[16]), "training_type": as_text(r[18]),
            "legacy_course_id": cid,
        })

    # process chronologically so "current department" ends on the latest training
    rows.sort(key=lambda x: (x["start_date"] or f"{x['fiscal_year'] or 0}-00-00", x["legacy_course_id"]))

    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("historical_*.sql"):
        old.unlink()
    (OUT / "historical_rows.json").write_text(json.dumps(rows, ensure_ascii=False))
    n_chunks = math.ceil(len(rows) / CHUNK)
    opts = json.dumps({"data_source": "Historical Excel", "source_file": src.name, "import_type": "historical"},
                      ensure_ascii=False)
    for i in range(n_chunks):
        chunk, seen = [], set()
        for r in rows[i * CHUNK:(i + 1) * CHUNK]:
            code = r.get("employee_code")
            slim = {k: v for k, v in r.items() if v is not None}
            if code and code in seen:
                for k in EMP_STATIC:
                    slim.pop(k, None)
            seen.add(code)
            chunk.append(slim)
        payload = json.dumps(chunk, ensure_ascii=False, separators=(",", ":"))
        assert "$asw$" not in payload
        sql = (f"-- ASW Training Record — historical migration chunk {i + 1}/{n_chunks} ({len(chunk)} rows)\n"
               f"select public.import_training_rows($asw${payload}$asw$::jsonb, $asw${opts}$asw$::jsonb) - 'rows' - 'issues';\n")
        (OUT / f"historical_{i + 1:02d}.sql").write_text(sql)
    print(f"rows={len(rows)} participants={sum(1 for r in rows if r.get('employee_code'))} "
          f"session_only={sum(1 for r in rows if not r.get('employee_code'))} chunks={n_chunks}")


if __name__ == "__main__":
    main()

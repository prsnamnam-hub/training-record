# ASW Training Record — Phase 1–3: Excel Analysis, Data Mapping, Database Design

> ASW Training Record — Training Record & Training Expense Management
> ผลวิเคราะห์ ณ 24-Sep-2026 · Source: `Training/รายการหลักสูตรอบรม_update 2569 (EmpInfo_Date).xlsx`

---

## 1. File Analysis

ใน Folder `Training/` มี Excel จริง **1 ไฟล์** (อีกไฟล์ `~$รายการ...xlsx` เป็น lock file ของ Excel ขนาด 165 bytes — ไม่ใช่ข้อมูล, ข้าม)

| File | Sheet | Records | Purpose |
|---|---|---:|---|
| รายการหลักสูตรอบรม_update 2569 (EmpInfo_Date).xlsx | **Training Record** | 7,325 | ข้อมูลหลัก: 1 แถว = พนักงาน 1 คน × 1 รอบอบรม (คน-ครั้ง) + ข้อมูลพนักงานจาก Employee Info Report |
| 〃 | **Training Courses** | 399 | รายการรอบอบรม (Course ID 1–399) ชื่อ/วันที่/ประเภท + คอลัมน์คำนวณจำนวนผู้เข้าอบรม |
| 〃 | **Employee Check** | 195 | ผลตรวจรหัส/ชื่อพนักงานที่ไม่ตรงกับ Employee Info Report (Data Quality log) |
| 〃 | **Dashboard** | 1 หน้า (B2:Q125) | Dashboard สรุปการอบรม, 6 Charts, ตัวเลือกปี/เดือน |
| 〃 | **Dashboard Data** | 79 ฝ่าย + ตารางเดือน | ตารางช่วยคำนวณ Dashboard (ลำดับเดือน, คน-ครั้งตามฝ่าย) |

Named ranges: `SelYear`, `SelMonth`, `TR_*` (Training Record), `TC_*` (Training Courses) — ใช้โดยสูตร COUNTIFS ของ Dashboard

### สถิติรายปี (ปี พ.ศ.)

| ปี | คน-ครั้ง | รอบอบรม (Course ID) | พนักงาน (คน, ไม่ซ้ำ) | ชื่อหลักสูตร |
|---|---:|---:|---:|---:|
| 2566 (2023) | 2,516 | 135 | 621 | 133 |
| 2567 (2024) | 2,081 | 122 | 662 | 120 |
| 2568 (2025) | 1,625 | 71 | 595 | 71 |
| 2569 (2026) | 1,103 | 60 | 528 | 57 |
| **รวม** | **7,325** | **388** (+11 รอบที่ยังไม่มีผู้เข้า) | **967** | **342** |

ช่วงวันที่: 03-Jan-2023 → 21-Nov-2026 (มี 15 แถวที่วันที่อยู่ในอนาคต = ลงทะเบียนล่วงหน้า)

---

## 2. Column Analysis — Sheet `Training Record` (A1:AT7326)

| Col | Header | Type | Non-null | Unique | หมายเหตุ |
|---|---|---|---:|---:|---|
| B | รหัส*ใหม่ | int | 7,325 | 967 | รหัสพนักงาน (ไม่มี 0 นำหน้า) — ตรงกับ U ทุกแถว ยกเว้น 1 รหัสที่ไม่พบใน HR master |
| C–F | คำนำหน้าชื่อ / ชื่อไทย / นามสกุลไทย / ชื่อเล่น | str | 7,325 | | ข้อมูลเดิมจากไฟล์ประวัติอบรม (legacy) |
| G | Level | int | 7,324 | 30 | **548 แถวเป็น `#N/A`** (-2146826246) — 170 คน |
| H | ตำแหน่ง | str | 7,324 | 40 | 548 แถว `#N/A` |
| I | Group | str | 7,324 | 4 | Executive / Management / Officer (+ #N/A) |
| J | กลุ่มธุรกิจ | str | 7,324 | 17 | Head Office, BUG1–4, BUSN, TM, AAP ... (99 แถว #N/A) |
| K | รหัสหน่วยงาน | str | 7,324 | 70 | Department code — 6 รหัสมีชื่อฝ่ายมากกว่า 1 แบบ |
| L | ฝ่าย | str | 7,325 | 80 | **Department** (56 แถว #N/A, มีชื่อสะกดต่างกัน เช่น Legal and Business Relations / Legal And Business Relation) |
| M | พ้นสภาพ | int (Excel serial date) | 1,453 | | วันที่พ้นสภาพ (legacy, เก็บเป็นตัวเลข) |
| N | Status | str | 7,325 | 5 | Active 6,016 / In-Active 1,251 / Title 55 / คนขับรถ 2 / Messenger 1 |
| O | ชื่อหลักสูตร | str | 7,325 | 342 | Course title (มีการขึ้นบรรทัดใหม่ในชื่อ) |
| P | วันที่อบรม | date | 7,148 | 321 | Start date — **177 แถวปี 2566 ไม่มีวันที่** |
| Q | เดือนที่อบรม | str | 7,141 | 19 | เดือนไทยย่อ มีค่าไม่มาตรฐาน: `สิงหาคม`, `กค.`, `กันยายน`, ช่วงเดือน `ม.ค.-มี.ค.` |
| R | ปีที่อบรม | int/str | 7,325 | 5 | พ.ศ. (มี `2566-67` 1 แถว) |
| S | ประเภท Inhouse / Public | str | 7,325 | 3 | Inhouse 6,542 / Public 625 / ONLINE 158 |
| T | ค่าที่บันทึก (ตามไฟล์เดิม) | num | 7,325 | 5 | 1 (7,293), 2 (17), 0.5 (6), 4 (5), 3 (4) — **ไม่สัมพันธ์กับจำนวนวัน → ต้องยืนยันความหมาย** |
| U | รหัสพนักงาน | str (5 หลัก) | 7,324 | 966 | **Employee ID (Employee Info Report)** — ใช้เป็น key หลัก |
| V–Y | คำนำหน้า / ชื่อ / นามสกุล / ชื่อเล่น | str | 7,324 | | ชื่อปัจจุบันจาก HR master |
| Z–AA | รหัสบริษัท / ชื่อบริษัท | str | 7,324 | 7 | **Company** |
| AB–AC | AreaCode / AreaName | str | 7,324 | 7 | Personnel area (≈ บริษัท) |
| AD–AE | SubareaCode / SubareaName | str | 7,324 | 2 | สำนักงาน / ไซท์ (Work location) |
| AF–AG | รหัส/ชื่อกลุ่มระดับพนักงาน | str | 7,324 | 10 | **Employee Level Group** เช่น ผู้บริหาร 3 (L26–L30) … พนักงานสัญญาจ้าง (L0) |
| AH–AI | รหัส/ชื่อระดับพนักงาน | str | 7,324 | 29 | **Position level** เช่น ผู้จัดการแผนก |
| AJ | วันที่จ้างงาน | date | 7,324 | | Hire date |
| AK | วันที่ผ่านทดลองงาน | date | 7,319 | | Probation passed date |
| AL | วันที่พ้นสภาพ | date | 1,600 | | Termination date (369 คน) |
| AM | ผลตรวจสอบ | str | 7,325 | 7 | OK 6,701 / ชื่อไม่ตรง / ชื่อเล่นไม่ตรง / คำนำหน้าไม่ตรง / ไม่พบรหัส |
| AN | วันที่สิ้นสุด | date | 7,145 | | End date |
| AO | Course ID | int | 7,325 | 388 | **FK → Training Courses = รอบอบรม (session)** |
| AP–AT | ปีอบรม / เดือนอบรม / คนแรกของปี / จำนวนหลักสูตรของคนในปี / คนแรกของเดือน | formula | | | Helper สำหรับ Dashboard → **ไม่ import, ระบบคำนวณเองด้วย SQL** |

## 3. Column Analysis — Sheet `Training Courses` (O1:Y400)

| Col | Header | หมายเหตุ |
|---|---|---|
| O | ชื่อหลักสูตร | ตรงกับ Training Record 100% |
| P | วันที่อบรม | Start date |
| Q | เดือนที่อบรม | เดือนไทย |
| R | ปีที่อบรม | พ.ศ. |
| S | ประเภท Inhouse / Public | Inhouse 186 / Public 211 / ONLINE 2 (ตรงกับ Training Record 100%) |
| T | วันที่สิ้นสุด | End date |
| U | Course ID | 1–399, unique |
| V–Y | ปีอบรม / เดือนอบรม / จำนวนผู้เข้าอบรม / ลำดับ | formula helper → ไม่ import |

**ข้อค้นพบสำคัญ:** `Course ID` หนึ่งค่า = ชื่อ + วันที่ + ประเภท ชุดเดียว (ไม่มี ID ใดมีหลายชื่อ/หลายวันที่) แต่ชื่อเดียวกันมีหลาย ID ได้ (22 ชื่อ เช่น `ปฐมนิเทศพนง.ใหม่รุ่นที่1` มี 4 ID = คนละปี)
→ **Course ID ใน Excel คือ "Training Session" ไม่ใช่ "Course"**
→ Course Master ต้องสร้างจากชื่อหลักสูตร (distinct title) และ Session = Course ID เดิม

11 รอบที่ไม่มีผู้เข้าอบรม: รอบในแผน (ปฐมนิเทศรุ่น 10–12 ปี 2569, Teambuilding BU1/BU2/BU4/SN), รอบที่ไม่มีวันที่ (Facet5 Accreditation, Leadership Act) → import เป็น Session สถานะ `Planned` / `Scheduled`

---

## 4. Field Mapping

| Excel Field (Sheet!Col) | System Field | Table | Description |
|---|---|---|---|
| TR!U รหัสพนักงาน (fallback TR!B zero-pad 5) | employee_code | employees | รหัสพนักงาน 5 หลัก (text) |
| TR!V คำนำหน้า | title_th | employees | คำนำหน้า (จาก HR master) |
| TR!W ชื่อ | first_name_th | employees | |
| TR!X นามสกุล | last_name_th | employees | |
| TR!Y ชื่อเล่น | nickname | employees | |
| TR!C–F | legacy_title/first/last/nickname | employees | ชื่อตามไฟล์ประวัติเดิม (ใช้ตอนชื่อ HR ไม่มี) |
| TR!Z/AA รหัส/ชื่อบริษัท | code / name | companies | 7 บริษัท |
| TR!AB/AC AreaCode/AreaName | area_code / area_name | companies | |
| TR!AD/AE Subarea | work_location_code / name | employees | สำนักงาน / ไซท์ |
| TR!J กลุ่มธุรกิจ | code | business_groups | Head Office, BUG1–4 … |
| TR!K รหัสหน่วยงาน | code | departments | |
| TR!L ฝ่าย | name | departments | ชื่อฝ่าย (normalize ชื่อที่สะกดต่างกัน) |
| TR!AF/AG กลุ่มระดับพนักงาน | code / name | level_groups | 10 กลุ่ม — ใช้ใน Dashboard |
| TR!AH/AI ระดับพนักงาน | code / name | positions | 29 ระดับตำแหน่ง |
| TR!G Level | job_level | employees | L0–L30 (#N/A → null) |
| TR!H ตำแหน่ง | job_title | employees | ชื่อตำแหน่ง EN |
| TR!I Group | job_group | employees | Executive/Management/Officer |
| TR!N Status | employment_status | employees | Active / In-Active / Title / คนขับรถ / Messenger |
| TR!AJ วันที่จ้างงาน | hire_date | employees | |
| TR!AK วันที่ผ่านทดลองงาน | probation_date | employees | |
| TR!AL วันที่พ้นสภาพ (fallback TR!M serial) | termination_date | employees | |
| TR!AM ผลตรวจสอบ | name_check_result | employees | Data quality flag |
| TR!O / TC!O ชื่อหลักสูตร | course_name | training_courses | distinct title (trim, รวม whitespace) |
| TC!U Course ID | legacy_course_id | training_sessions | key เดิมสำหรับกันซ้ำตอน re-import |
| TC!P วันที่อบรม | start_date | training_sessions | |
| TC!T วันที่สิ้นสุด | end_date | training_sessions | |
| TC!R ปีที่อบรม | fiscal_year_be | training_sessions | ใช้เมื่อไม่มีวันที่ (177 แถวปี 2566) |
| TC!Q เดือนที่อบรม | legacy_month_text | training_sessions | เก็บค่าเดิมไว้อ้างอิง (มีค่าช่วงเดือน) |
| TC!S ประเภท | training_type_id | training_sessions | Inhouse / Public / Online |
| TR!AO Course ID | session_id (FK) | training_participants | |
| TR!T ค่าที่บันทึก | legacy_value | training_participants | เก็บค่าเดิมไว้ก่อน รอยืนยันความหมาย |
| — | data_source, import_batch_id, import_date | ทุกตาราง transaction | `Historical Excel` |
| EC!* (Employee Check) | — | import_issues | นำเข้าเป็น Data Quality log ของ batch แรก |

**ไม่มีใน Excel** (ตรวจแล้วทุก sheet): Training Hours, Training Category, Trainer, Provider, Location, Start/End Time, Score, Certificate, Evaluation, Attendance status, Cost, Food Cost, Other Cost, Budget, Actual
Dashboard เดิมระบุชัด (B125): *"ไม่มีข้อมูลชั่วโมงอบรมและค่าใช้จ่าย"*
→ Field เหล่านี้สร้างในระบบเป็นช่องว่างให้กรอกต่อ **ไม่สร้าง Mock Data**; ข้อมูลย้อนหลังจะแสดง "ไม่มีข้อมูล" สำหรับชั่วโมง/ค่าใช้จ่าย

---

## 5. Master Data ที่พบ

| Master | จำนวน | ที่มา |
|---|---:|---|
| Employee | 967 (966 มีใน HR master + 1 รหัสที่ไม่พบ) | TR!U–AL |
| Company | 7 | TR!Z–AA (แอสเซท ไวส์, ร่มโพธิ์, เทรเชอร์ เอ็ม, ดิจิ โทไนซ์, แอสเซท เอ พลัส, ดับบลิวเอชบี, ดิ เอสไควร์) |
| Business Group | 16 | TR!J |
| Department (ฝ่าย) | 79 (หลัง normalize ~75) | TR!K–L, Dashboard Data!A20:A98 |
| Level Group | 10 | TR!AF–AG |
| Position Level | 29 | TR!AH–AI |
| Work Location | 2 | สำนักงาน / ไซท์ |
| Training Type | 3 | Inhouse / Public / Online |
| Course (ชื่อหลักสูตร) | 342 | TR!O |
| Training Session | 399 | TC!U |
| Section / Training Category / Trainer / Provider / Expense Category | **ไม่พบ** | สร้างเป็น Master ว่าง / Expense Category ตั้งค่าเริ่มต้นตาม requirement ข้อ 16 |

หมายเหตุ: Excel ไม่มีระดับ "Section" — ระดับที่ใกล้ที่สุดคือ Business Group (J) > Department (K/L)

---

## 6. Dashboard Analysis (Sheet `Dashboard`)

**Filter:** ปีที่รายงาน (พ.ศ. 2566–2569) + เดือนที่รายงาน (ม.ค.–ธ.ค.) — ช่องสีเหลือง

| Section | Row | เนื้อหา | Calculation |
|---|---|---|---|
| Header | 2–5 | ชื่อ, แหล่งข้อมูล, ตัวเลือก, ช่วงสะสม, วันที่พิมพ์ | |
| **KPI เดือน** | 7–10 | หลักสูตรที่จัด · คน-ครั้ง (เทียบเดือนก่อน) · พนักงาน (ไม่ซ้ำ) · สัดส่วน Inhouse:Public:Online | COUNT session / COUNT rows / COUNT DISTINCT emp / ratio |
| **KPI สะสม YTD** | 12–15 | หลักสูตรสะสม (+ทั้งปีรวมที่วางแผน) · คน-ครั้งสะสม (เทียบปีก่อนช่วงเดียวกัน) · พนักงานทั้งปี (เฉลี่ยหลักสูตร/คน) · **ผ่านเป้า ≥ 2 หลักสูตร/ปี** (คน, %) | Target = 2 courses/person/year |
| **Monthly Trend** | 17–32 | ตาราง 12 เดือน: หลักสูตร, คน-ครั้ง, Inhouse, Public, Online, พนักงาน + แถวรวม + จำนวนที่ไม่มีวันที่ | Chart 1: Stacked bar คน-ครั้งตามประเภทรายเดือน |
| **Yearly Comparison** | 34–40 | ปี 2566–2569: หลักสูตร, คน-ครั้ง, พนักงาน, เฉลี่ย/คน, ผ่านเป้า, % ผ่านเป้า, % Inhouse | Chart 2: คน-ครั้ง / พนักงาน รายปี |
| **By Type** | 50–55 | Inhouse/Public/ONLINE: หลักสูตร, คน-ครั้ง, สัดส่วน | Chart 3: Doughnut |
| **By Company** | 64–73 | 7 บริษัท + "ไม่พบข้อมูล": คน-ครั้ง, พนักงาน, สัดส่วน | Chart 4: Bar |
| **By Level Group** | 78–89 | 10 กลุ่มระดับ: คน-ครั้ง, พนักงาน, เฉลี่ย/คน | Chart 5: Bar |
| **Top 10 Departments** | 92–103 | ฝ่าย, คน-ครั้ง, พนักงาน, เฉลี่ย/คน | Chart 6: Bar |
| **Top 10 Courses** | 106–117 | ชื่อหลักสูตร, วันที่, ประเภท, คน-ครั้ง | Table |
| **Data Notes** | 120–125 | นิยาม, รอบในอนาคต, จำนวนที่ไม่พบใน HR master | |

**นิยามที่ต้องคงไว้ในระบบ:** `คน-ครั้ง` = จำนวน participant rows · `พนักงาน (คน)` = distinct employee · ปี/เดือนอิงวันที่เริ่ม; ไม่มีวันที่ → ใช้ปีจากคอลัมน์ปี และไม่นับรายเดือน · ผ่านเป้า = พนักงานที่อบรม ≥ 2 ครั้งในปี / พนักงานที่อบรมอย่างน้อย 1 ครั้ง

**Web Dashboard = โครงเดิมจาก Excel + ส่วนเพิ่มตาม requirement:**
Filter เพิ่ม Department, Business Group, Level Group, Company, Training Type, Course (multi-select) · KPI เพิ่ม Training Hours / Cost / Cost per Person (แสดงเมื่อมีข้อมูล) · Expense breakdown · Key Insights คำนวณจาก query

## 7. Report Analysis

| Report | มีใน Excel | ในระบบ |
|---|---|---|
| Monthly summary (คน-ครั้ง/หลักสูตร/พนักงาน) | ✅ Dashboard | Monthly Training Report + Monthly Management Report |
| Yearly comparison + Target ≥2 | ✅ | Year Comparison / Training Target Report |
| By Type, Company, Level Group, Department | ✅ | Department / Company / Level Group Report |
| Top Courses | ✅ | Course Report / Course Summary |
| Employee Check (Data Quality) | ✅ | Import Center → Data Quality Report |
| Employee Training History | ❌ (ทำได้จากข้อมูล) | ✅ เพิ่ม |
| **Employee ที่ยังไม่ผ่านเป้า 2 หลักสูตร** | ❌ | ✅ แนะนำเพิ่ม (ข้อมูลรองรับ) |
| Training Cost / Budget vs Actual / Provider / Trainer / Category | ❌ ไม่มีข้อมูล | ✅ สร้างไว้ ใช้กับข้อมูลใหม่ |

---

## 8. Data Quality Issues & Migration Rules

| # | Issue | จำนวน | Rule |
|---|---|---:|---|
| 1 | `#N/A` ใน Level/ตำแหน่ง/Group/กลุ่มธุรกิจ/ฝ่าย | 548 / 99 / 56 แถว | ใช้ข้อมูลจาก HR columns (U–AL); legacy #N/A → null |
| 2 | 1 รหัสพนักงานไม่พบใน HR master | 1 แถว | import พนักงานจากชื่อ legacy, flag `not_in_hr_master` |
| 3 | ชื่อไม่ตรงกับ HR master | 624 แถว | ใช้ชื่อ HR เป็นหลัก เก็บชื่อ legacy ไว้ |
| 4 | Participant ซ้ำ (emp + Course ID เดียวกัน) | 3 คู่ (Course ID 348 ×2, 356 ×1) | import 1 แถว, บันทึกแถวซ้ำใน import_issues |
| 5 | ไม่มีวันที่อบรม | 177 แถว (ปี 2566) | start_date null, ใช้ fiscal_year_be |
| 6 | เดือนไม่มาตรฐาน / ช่วงเดือน | 22 แถว | คำนวณเดือนจากวันที่; เก็บข้อความเดิมใน legacy_month_text |
| 7 | ปี `2566-67` | 1 แถว | ใช้ปีจากวันที่ (2566) |
| 8 | ชื่อฝ่ายสะกดต่างกัน / 6 รหัสหน่วยงานมีหลายชื่อ | | ใช้ รหัสหน่วยงาน เป็น key + alias table |
| 9 | พนักงานเปลี่ยนฝ่าย | 2 คน | snapshot ฝ่าย ณ วันอบรมไว้ใน participant |
| 10 | วันที่พ้นสภาพ (M) เป็น Excel serial | 1,453 | แปลงเป็น date |
| 11 | Session ในอนาคต / ไม่มีผู้เข้า | 11 | import เป็น session สถานะ Planned/Scheduled |

### Unique Keys (จากข้อมูลจริง ไม่เดา)

| Table | Unique Key | เหตุผล |
|---|---|---|
| employees | employee_code | unique 966 + 1 |
| training_courses | normalized course_name | 342 titles |
| training_sessions | legacy_course_id (historical) · course_id + start_date + training_type (ใหม่) | Excel Course ID = 1 ชื่อ + 1 วันที่ + 1 ประเภทเสมอ |
| training_participants | session_id + employee_id | พบซ้ำเพียง 3 คู่ ซึ่งเป็นข้อมูลซ้ำจริง |

---

## 9. Database Design (Supabase / PostgreSQL)

```
companies ─┐
business_groups ─┐   level_groups   positions
departments ─────┴──> employees <─────┘
                          │
training_categories ┐     │
training_types ─────┼─> training_courses ──< training_sessions >── trainers / training_providers
                    │                          │         │
                    │                          │         └──< training_expenses >── expense_categories
                    │                          │                    └── training_expense_items (food qty × price)
                    │                          └──< training_participants (= training record + result)
                    │                                        └── training_evaluations
training_budgets (year × department/company)
import_batches ──< import_issues      audit_logs      users / roles
```

| Table | Key Columns |
|---|---|
| **companies** | id, code, name, area_code, area_name |
| **business_groups** | id, code, name |
| **departments** | id, code, name, business_group_id, aliases text[], is_active |
| **sections** | id, department_id, name (ว่าง — ไม่มีใน Excel) |
| **level_groups** | id, code, name, sort_order |
| **positions** | id, code, name, level_group_id |
| **employees** | id, employee_code UNIQUE, title_th, first_name_th, last_name_th, nickname, legacy_*, company_id, department_id, section_id, position_id, level_group_id, job_level, job_title, job_group, work_location, employment_type, employment_status, hire_date, probation_date, termination_date, name_check_result, data_source, import_batch_id, audit cols |
| **training_types** | id, name (Inhouse / Public / Online), is_internal |
| **training_categories** | id, name |
| **trainers** | id, name, is_internal, employee_id, provider_id |
| **training_providers** | id, name, contact |
| **training_courses** | id, course_code, course_name UNIQUE(normalized), category_id, training_type_id, objective, provider_id, trainer_id, standard_hours, standard_cost, status (Active/Inactive), remark, audit cols |
| **training_sessions** | id, session_code, legacy_course_id UNIQUE, course_id, session_name (ชื่อรุ่นเต็ม), training_type_id, start_date, end_date, start_time, end_time, training_hours, fiscal_year_be, legacy_month_text, trainer_id, provider_id, location, status (Draft/Planned/Scheduled/In Progress/Completed/Cancelled), remark, data_source, import_batch_id, import_date, audit cols |
| **training_participants** (= Training Record) | id, session_id, employee_id, UNIQUE(session_id, employee_id), snapshot: department_id, company_id, level_group_id, position_id; attendance_status, completion_status, training_hours (override), score, certificate_no, certificate_url, evaluation_score, legacy_value, remark, data_source, import_batch_id, audit cols |
| **training_evaluations** | id, participant_id, evaluation_type, score, comment |
| **expense_categories** | id, name, group (Course Fee/Trainer Fee/Food/Beverage/Accommodation/Transportation/Venue/Material/Certificate/Equipment/Other), is_system, is_active |
| **training_expenses** | id, session_id **NOT NULL**, expense_category_id, description, meal_type, quantity, unit_price, amount (= quantity × unit_price, generated), expense_date, vendor, invoice_no, remark, audit cols |
| **training_budgets** | id, fiscal_year, company_id, department_id, expense_category_id, budget_amount |
| **import_batches** | id, source_file, import_type, data_source (Historical Excel / Excel Import), total, valid, invalid, duplicate, imported, status, imported_by, imported_at |
| **import_issues** | id, batch_id, sheet, row_no, severity, issue_type, message, raw jsonb |
| **audit_logs** | id, table_name, record_id, action (INSERT/UPDATE/DELETE), old_data jsonb, new_data jsonb, changed_by, changed_at |
| **profiles / roles** | user_id → role (admin / hr_training / viewer) ใช้กับ Supabase Auth + RLS |

**Soft delete:** ทุกตารางหลักมี `deleted_at`, `deleted_by` (ห้ามลบ Historical Data)
**Audit:** trigger บันทึก old/new ลง audit_logs อัตโนมัติ
**Analytics:** SQL views / RPC — `v_participant_fact` (join ทุกมิติ, ปี/เดือนคำนวณ), `v_session_cost` (total cost, cost/participant, cost/hour), `rpc_dashboard(filters jsonb)` เพื่อให้ Dashboard/Report ใช้ query เดียวกัน รองรับ 100k+ rows ด้วย index บน (start_date), (employee_id), (session_id), (department_id)

---

## 10. คำถามที่ต้องยืนยันก่อน Phase 4

1. **คอลัมน์ T "ค่าที่บันทึก (ตามไฟล์เดิม)"** (1 / 2 / 0.5 / 3 / 4) หมายถึงอะไร — จำนวนวัน, ชั่วโมง, หรือจำนวนครั้ง? ถ้าเป็นวัน/ชั่วโมงจะใช้เป็น Training Hours ย้อนหลังได้
2. **Course Master:** ให้รวมชื่อรุ่นเป็นหลักสูตรเดียวกันหรือไม่ เช่น `ปฐมนิเทศพนง.ใหม่รุ่นที่1…12` → Course "ปฐมนิเทศพนักงานใหม่" + Session รุ่นที่ 1…12 (แนะนำ) หรือใช้ชื่อตามเดิม 342 หลักสูตร
3. **Supabase:** มี Project อยู่แล้วหรือไม่ (URL + anon key) หรือให้เริ่มด้วย Supabase local (CLI/Docker) ก่อน
4. **Fiscal year:** ปีรายงานเป็นปีปฏิทิน (ม.ค.–ธ.ค.) ตาม Dashboard เดิมใช่หรือไม่

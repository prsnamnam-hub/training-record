export const STATUS = ['Draft', 'Planned', 'Scheduled', 'In Progress', 'Completed', 'Cancelled']
export const SOURCES = ['Historical Excel', 'System Entry', 'Excel Import']
export const ATTENDANCE = ['Registered', 'Attended', 'Absent', 'Cancelled']
export const COMPLETION = ['Completed', 'Not Completed', 'In Progress', 'Pending']
export const MEAL_TYPES = ['Breakfast', 'Lunch', 'Dinner', 'Coffee Break', 'Snack']
export const MEAL_TH = { Breakfast: 'อาหารเช้า', Lunch: 'อาหารกลางวัน', Dinner: 'อาหารเย็น', 'Coffee Break': 'Coffee Break', Snack: 'ของว่าง' }
export const COST_GROUPS = ['Course Fee', 'Trainer Fee', 'Food', 'Accommodation', 'Transportation', 'Venue', 'Material', 'Other']
export const statusColor = (s) => ({ Completed: 'green', Scheduled: 'blue', 'In Progress': 'purple', Planned: 'amber', Draft: '', Cancelled: 'red' }[s] || '')
export const typeColor = (t) => ({ Inhouse: 'blue', Public: 'amber', Online: 'green' }[t] || '')
export const attendColor = (s) => ({ Attended: 'green', Registered: 'blue', Absent: 'red', Cancelled: 'red' }[s] || '')

require "chunky_png"
require "stringio"

if Rails.env.production?
  puts "Production sample seeds are disabled. Use production:bootstrap_owner."
else

def design_preview_blob(background, fabric, accent, variation)
  image = ChunkyPNG::Image.new(480, 600, ChunkyPNG::Color.from_hex(background))
  fabric_color = ChunkyPNG::Color.from_hex(fabric)
  accent_color = ChunkyPNG::Color.from_hex(accent)
  soft_accent = ChunkyPNG::Color.rgba(
    ChunkyPNG::Color.r(accent_color), ChunkyPNG::Color.g(accent_color), ChunkyPNG::Color.b(accent_color), 150
  )

  image.rect(18, 18, 461, 581, soft_accent, ChunkyPNG::Color::TRANSPARENT)
  image.circle(240, 144, 45, fabric_color, ChunkyPNG::Color::TRANSPARENT)
  image.polygon(
    [ 188, 165, 292, 165, 338, 260, 310, 286, 292, 236, 306, 516, 174, 516, 188, 236, 170, 286, 142, 260 ],
    fabric_color, fabric_color
  )
  image.circle(240, 165, 23 + (variation % 3) * 4, accent_color, ChunkyPNG::Color::TRANSPARENT)

  4.times do |index|
    y = 300 + (index * 42) + (variation % 2) * 10
    image.line(188, y, 292, y, soft_accent)
  end
  7.times do |index|
    x = 197 + index * 14
    image.circle(x, 228 + (variation % 4) * 8, 3, accent_color, accent_color)
  end

  image.to_blob
end

def seed_design(shop:, actor:, attributes:, palette:, variation:)
  design = shop.designs.find_or_initialize_by(title: attributes.fetch(:title))
  design.assign_attributes(attributes.merge(uploaded_by: actor, rights_confirmed_by: actor, rights_confirmed_at: Time.current))
  unless design.images.attached?
    design.images.attach(
      io: StringIO.new(design_preview_blob(*palette, variation)),
      filename: "#{attributes.fetch(:title).parameterize}.png",
      content_type: "image/png"
    )
  end
  design.save!
  design.update_column(:primary_image_blob_id, design.images.attachments.first.blob_id) if design.primary_image_blob_id.blank?
  design
end

def seed_design_collection(shop:, actor:, name:, description:, visibility:, designs:, position:, active: true, legacy_names: [])
  collection = shop.design_collections.where(name: [ name, *legacy_names ]).first_or_initialize
  collection.assign_attributes(
    created_by: actor, name: name, description: description, visibility: visibility, active: active, position: position
  )
  collection.save!
  designs.each_with_index do |design, index|
    item = collection.design_collection_items.find_or_initialize_by(design: design)
    item.assign_attributes(shop: shop, added_by: actor, position: index)
    item.save!
  end
  collection
end

shop = Shop.find_by(slug: "default-shop") || Shop.find_or_create_by!(slug: "puitei-studio") do |record|
  record.name = "Puitei Chhakchhuak"
  record.country = "India"
end

branch = shop.branches.find_or_create_by!(code: "AIZAWL") do |record|
  record.name = "Aizawl"
  record.phone = "+91 98765 43210"
  record.email = "shop@example.test"
  record.address = "New Market, Aizawl, Mizoram"
  record.locale = "en"
  record.time_zone = "Asia/Kolkata"
end

branch.shop_setting.update!(
  shop_name: "Puitei Chhakchhuak",
  phone: branch.phone,
  whatsapp_number: branch.phone,
  email: branch.email,
  address: branch.address,
  currency: "INR",
  measurement_unit: "inches",
  invoice_prefix: "TLR",
  tax_rate: 0,
  default_delivery_days: 14,
  low_stock_threshold: 5,
  locale: "en",
  business_hours: {
    "monday" => "09:00-18:00",
    "tuesday" => "09:00-18:00",
    "wednesday" => "09:00-18:00",
    "thursday" => "09:00-18:00",
    "friday" => "09:00-18:00",
    "saturday" => "09:00-17:00",
    "sunday" => "closed"
  }
)

password = if Rails.env.test?
  ENV.fetch("SEED_PASSWORD") { SecureRandom.base64(24) }
else
  ENV.fetch("SEED_PASSWORD")
end

staff = [
  [ "Owner", "owner@puitei.test", :owner ],
  [ "Shop Manager", "manager@puitei.test", :manager ],
  [ "Reception Desk", "reception@puitei.test", :receptionist ],
  [ "Cashier", "cashier@puitei.test", :cashier ],
  [ "Senior Tailor", "tailor@puitei.test", :tailor ],
  [ "Cutting Staff", "cutting@puitei.test", :cutting_staff ],
  [ "Embroidery Staff", "embroidery@puitei.test", :embroidery_staff ],
  [ "Ironing Staff", "ironing@puitei.test", :ironing_staff ]
]

staff.each do |name, email, role|
  User.find_or_initialize_by(email: email).tap do |user|
    user.assign_attributes(name: name, role: role, branch: branch, active: true)
    user.password = password if user.new_record?
    user.save!
    shop.memberships.find_or_initialize_by(user: user).tap do |membership|
      membership.assign_attributes(
        branch: branch, role: role, active: true, employee_code: user.employee_code,
        joined_on: user.joined_on, pay_basis: user.pay_basis, pay_rate: user.pay_rate, accepted_at: Time.current
      )
      membership.save!
    end
  end
end
shop.update!(created_by: User.find_by!(email: "owner@puitei.test"))

template_fields = {
  "blouse" => %w[bust waist shoulder armhole sleeve_length sleeve_round front_neck_depth back_neck_depth blouse_length],
  "kurti" => %w[bust waist hip shoulder armhole sleeve_length sleeve_round neck garment_length],
  "dress" => %w[bust waist hip shoulder armhole sleeve_length garment_length],
  "gown" => %w[bust waist hip shoulder armhole sleeve_length waist_length garment_length],
  "lehenga" => %w[waist hip garment_length],
  "skirt" => %w[waist hip garment_length],
  "shirt" => %w[chest waist shoulder neck armhole sleeve_length sleeve_round garment_length],
  "trouser" => %w[waist seat rise thigh knee bottom pant_length inseam],
  "suit" => %w[chest waist hip shoulder neck sleeve_length garment_length pant_length inseam],
  "school_uniform" => %w[chest waist hip shoulder sleeve_length garment_length pant_length],
  "custom_garment" => %w[chest bust waist hip shoulder sleeve_length garment_length]
}

required_fields = %w[chest bust waist garment_length pant_length]
template_fields.each do |garment_type, field_keys|
  template = MeasurementTemplate.find_or_create_by!(garment_type: garment_type) do |record|
    record.name = garment_type.humanize
    record.active = true
  end

  field_keys.each_with_index do |key, position|
    template.measurement_fields.find_or_create_by!(key: key) do |field|
      field.label = key.humanize
      field.position = position
      field.required = key.in?(required_fields)
    end
  end
end

sample_customers = [
  { full_name: "Lalhmingmawii", phone_number: "9862401001", whatsapp_number: "9862401001", city: "Aizawl", preferred_language: "lus", gender: :female },
  { full_name: "Rohit Sharma", phone_number: "9862401002", city: "Aizawl", preferred_language: "hi", gender: :male },
  { full_name: "Vanlalruata", phone_number: "9862401003", city: "Kolasib", preferred_language: "en", gender: :male },
  { full_name: "Zonunmawii", phone_number: "9862401004", city: "Aizawl", preferred_language: "lus", gender: :female },
  { full_name: "Lalrinpuii", phone_number: "9862401005", city: "Champhai", preferred_language: "lus", gender: :female },
  { full_name: "Anjali Verma", phone_number: "9862401006", city: "Aizawl", preferred_language: "hi", gender: :female },
  { full_name: "Malsawmdawngliana", phone_number: "9862401007", city: "Serchhip", preferred_language: "lus", gender: :male },
  { full_name: "Rosangpuii", phone_number: "9862401008", city: "Lunglei", preferred_language: "lus", gender: :female },
  { full_name: "Priya Das", phone_number: "9862401009", city: "Aizawl", preferred_language: "en", gender: :female },
  { full_name: "Lalhruaitluanga", phone_number: "9862401010", city: "Kolasib", preferred_language: "lus", gender: :male },
  { full_name: "Esther Lalduhawmi", phone_number: "9862401011", city: "Aizawl", preferred_language: "en", gender: :female },
  { full_name: "Rebecca Vanlalpari", phone_number: "9862401012", city: "Aizawl", preferred_language: "lus", gender: :female },
  { full_name: "Neha Kapoor", phone_number: "9862401013", city: "Silchar", preferred_language: "hi", gender: :female },
  { full_name: "Hmingthanmawii", phone_number: "9862401014", city: "Champhai", preferred_language: "lus", gender: :female },
  { full_name: "R. Lalbiakzuala", phone_number: "9862401015", city: "Aizawl", preferred_language: "en", gender: :male },
  { full_name: "Pooja Singh", phone_number: "9862401016", city: "Aizawl", preferred_language: "hi", gender: :female },
  { full_name: "Lalrammawii", phone_number: "9862401017", city: "Saitual", preferred_language: "lus", gender: :female },
  { full_name: "Jenny Zothanpuii", phone_number: "9862401018", city: "Aizawl", preferred_language: "en", gender: :female },
  { full_name: "C. Lalremruata", phone_number: "9862401019", city: "Lunglei", preferred_language: "lus", gender: :male },
  { full_name: "Mary Lalhlimpuii", phone_number: "9862401020", city: "Aizawl", preferred_language: "lus", gender: :female }
]

customers = sample_customers.map do |attributes|
  Customer.find_or_initialize_by(branch: branch, phone_number: attributes[:phone_number]).tap do |customer|
    customer.assign_attributes(attributes)
    customer.save!
  end
end

blouse_template = MeasurementTemplate.find_by!(garment_type: "blouse")
profile = customers.first.measurement_profiles.find_or_create_by!(name: "Everyday blouse", measurement_template: blouse_template) do |record|
  record.unit = "inches"
  record.fitting_notes = "Comfortable fit with a little ease at the armhole."
  record.posture_notes = "Slightly forward shoulders."
  record.preferences = "Three-quarter sleeves."
end

if profile.measurements.none?
  profile.record_measurement(
    created_by: User.find_by!(email: "reception@puitei.test"),
    measured_on: Date.current,
    values: {
      "bust" => "36", "waist" => "30", "shoulder" => "14", "armhole" => "16",
      "sleeve_length" => "16", "sleeve_round" => "11", "front_neck_depth" => "7",
      "back_neck_depth" => "3", "blouse_length" => "15"
    },
    notes: "Initial fitting measurement."
  )
end

sample_order = Order.find_or_initialize_by(customer: customers.first, notes: "Sample Phase 3 order")
if sample_order.new_record?
  sample_order.assign_attributes(
    branch: branch,
    created_by: User.find_by!(email: "reception@puitei.test"),
    ordered_on: Date.current,
    trial_date: Date.current + 7.days,
    delivery_date: Date.current + 14.days
  )
  sample_order.order_items.build(
    measurement: profile.latest_measurement,
    garment_name: "Everyday blouse",
    quantity: 1,
    unit_price: 1800,
    special_instructions: "Use the customer-provided fabric and matching lining."
  )
  sample_order.save!
  sample_order.confirm!
end


billing_order = Order.find_or_initialize_by(customer: customers.first, notes: "Sample Phase 5 billing order")
if billing_order.new_record?
  billing_order.assign_attributes(
    branch: branch,
    created_by: User.find_by!(email: "reception@puitei.test"),
    ordered_on: Date.current,
    trial_date: Date.current + 5.days,
    delivery_date: Date.current + 12.days,
    discount_amount: 100
  )
  billing_order.order_items.build(
    measurement: profile.latest_measurement,
    garment_name: "Celebration blouse",
    quantity: 1,
    unit_price: 2200,
    requires_embroidery: true,
    special_instructions: "Gold thread border with matching lining."
  )
  billing_order.save!
  billing_order.confirm!
end

if billing_order.payments.none?
  billing_order.record_payment(
    received_by: User.find_by!(email: "cashier@puitei.test"),
    amount: billing_order.total_amount / 2,
    payment_method: :cash,
    paid_on: Date.current,
    notes: "Sample advance payment"
  )
end

first_task = sample_order.reload.order_items.first.production_tasks.first
if first_task&.assigned_to.nil?
  first_task.assign!(
    User.find_by!(email: "owner@puitei.test"),
    User.find_by!(email: "cutting@puitei.test")
  )
end

inventory_seed = [
  { sku: "FAB-SILK-NVY", name: "Silk blend", category: :fabric, unit: :metre, color: "Midnight navy", cost_price: 620, selling_price: 790, reorder_level: 8, opening: 34, supplier_name: "Aizawl Textile House" },
  { sku: "LIN-COT-IVY", name: "Cotton lining", category: :lining, unit: :metre, color: "Warm ivory", cost_price: 145, selling_price: 190, reorder_level: 12, opening: 18, supplier_name: "Aizawl Textile House" },
  { sku: "THR-POLY-GLD", name: "Polyester embroidery thread", category: :thread, unit: :spool, color: "Muted gold", cost_price: 85, selling_price: 120, reorder_level: 10, opening: 9, supplier_name: "Mizoram Haberdashery" },
  { sku: "BTN-PEARL-12", name: "Pearl buttons 12 mm", category: :button, unit: :packet, color: "Pearl", cost_price: 110, selling_price: 150, reorder_level: 5, opening: 14, supplier_name: "Mizoram Haberdashery" },
  { sku: "ZIP-CON-09-BLK", name: "Concealed zip 9 inch", category: :zipper, unit: :piece, color: "Black", cost_price: 28, selling_price: 45, reorder_level: 20, opening: 16, supplier_name: "Mizoram Haberdashery" }
]

inventory_seed.each do |attributes|
  opening = attributes.delete(:opening)
  item = InventoryItem.find_or_initialize_by(branch: branch, sku: attributes[:sku])
  item.assign_attributes(attributes)
  item.save!
  if item.stock_movements.none?
    item.record_movement!(
      movement_type: :stock_in, quantity: opening, actor: User.find_by!(email: "manager@puitei.test"),
      reference: "OPENING-STOCK", notes: "Phase 6 sample opening balance"
    )
  end
end

sample_fabric = InventoryItem.find_by!(branch: branch, sku: "FAB-SILK-NVY")
sample_item = sample_order.order_items.first
if sample_fabric.reserved_for(sample_item).zero? && sample_item.stock_movements.none?
  sample_fabric.record_movement!(
    movement_type: :reservation, quantity: 2.5, actor: User.find_by!(email: "reception@puitei.test"),
    order_item: sample_item, reference: sample_order.order_number, notes: "Reserved for sample blouse"
  )
end

phase_seven_order = lambda do |note, garment|
  order = Order.find_or_initialize_by(customer: customers.first, notes: note)
  if order.new_record?
    order.assign_attributes(
      branch: branch, created_by: User.find_by!(email: "reception@puitei.test"),
      ordered_on: Date.current, trial_date: Date.current + 2.days, delivery_date: Date.current + 5.days
    )
    order.order_items.build(
      measurement: profile.latest_measurement, garment_name: garment, quantity: 1, unit_price: 1950,
      special_instructions: "Final quality check before customer handover."
    )
    order.save!
    order.confirm!
  end
  order
end

complete_production = lambda do |order|
  order.order_items.each do |item|
    item.production_tasks.order(:position).each do |task|
      task.start!(User.find_by!(email: "owner@puitei.test")) if task.pending?
      task.complete!(User.find_by!(email: "owner@puitei.test"), notes: "Phase 7 sample quality workflow") if task.in_progress?
    end
  end
end

ready_for_delivery = phase_seven_order.call("Sample Phase 7 ready order", "Ready collection blouse")
complete_production.call(ready_for_delivery) if ready_for_delivery.confirmed?

delivered_order = phase_seven_order.call("Sample Phase 7 delivered order", "Delivered occasion blouse")
complete_production.call(delivered_order) if delivered_order.confirmed?
if delivered_order.confirmed? && delivered_order.delivery.nil?
  delivered_order.deliver!(
    actor: User.find_by!(email: "manager@puitei.test"),
    attributes: {
      recipient_name: delivered_order.customer.full_name, recipient_phone: delivered_order.customer.phone_number,
      collection_method: :customer_pickup, acknowledged_by: delivered_order.customer.full_name,
      recipient_acknowledged: true, quality_checked: true, garment_count_verified: true,
      payment_status_confirmed: true, packaging_complete: true,
      notes: "Phase 7 sample customer handover"
    }
  )
end

expense_seed = [
  {
    description: "Workshop monthly rent", category: :rent, amount: 18_000,
    incurred_on: Date.current.beginning_of_month, vendor: "Chaltlang Properties",
    payment_method: :bank_transfer, reference_number: "RENT-#{Date.current.strftime('%Y-%m')}",
    recurrence_interval: :monthly, recorded_by: User.find_by!(email: "manager@puitei.test"),
    notes: "Phase 8 sample recurring operating cost"
  },
  {
    description: "Silk and lining purchase", category: :material_purchase, amount: 6_850,
    incurred_on: Date.current - 3.days, vendor: "Aizawl Textile House",
    payment_method: :upi, reference_number: "UPI-MATERIAL-#{Date.current.strftime('%Y%m')}",
    recurrence_interval: :one_time, recorded_by: User.find_by!(email: "owner@puitei.test"),
    notes: "Material replenishment for current orders"
  },
  {
    description: "Local delivery transport", category: :transport, amount: 420,
    incurred_on: Date.current, vendor: "City Taxi",
    payment_method: :cash, recurrence_interval: :one_time,
    recorded_by: User.find_by!(email: "reception@puitei.test"),
    notes: "Pending manager review sample"
  }
]

expense_seed.each do |attributes|
  Expense.find_or_create_by!(branch: branch, description: attributes[:description]) do |expense|
    expense.assign_attributes(attributes.merge(branch: branch, currency: branch.shop_setting.currency))
  end
end

workforce_profiles = {
  "owner@puitei.test" => { job_title: "Studio owner", phone_number: "+91 98624 02001", pay_basis: :monthly_salary, pay_rate: 45_000 },
  "manager@puitei.test" => { job_title: "Workshop manager", phone_number: "+91 98624 02002", pay_basis: :monthly_salary, pay_rate: 32_000 },
  "tailor@puitei.test" => { job_title: "Senior blouse tailor", phone_number: "+91 98624 02005", pay_basis: :piece_rate, pay_rate: 650 },
  "cutting@puitei.test" => { job_title: "Senior cutter", phone_number: "+91 98624 02006", pay_basis: :daily, pay_rate: 950 }
}
workforce_profiles.each do |email, attributes|
  user = User.find_by!(email: email)
  user.update!(attributes)
  user.memberships.find_by!(shop: shop).update!(attributes.slice(:job_title, :pay_basis, :pay_rate))
end

sample_attendance = AttendanceRecord.find_or_initialize_by(user: User.find_by!(email: "manager@puitei.test"), work_date: Date.current - 1.day)
if sample_attendance.new_record?
  sample_attendance.assign_attributes(
    branch: branch, checked_in_at: 1.day.ago.change(hour: 9, min: 0),
    checked_out_at: 1.day.ago.change(hour: 17, min: 30), notes: "Phase 9 sample attendance"
  )
  sample_attendance.save!
  StaffEvent.record!(staff_member: sample_attendance.user, actor: sample_attendance.user, event_type: "checked_in", details: { attendance_id: sample_attendance.id })
  StaffEvent.record!(staff_member: sample_attendance.user, actor: sample_attendance.user, event_type: "checked_out", details: { attendance_id: sample_attendance.id })
end

sample_leave = LeaveRequest.find_or_initialize_by(user: User.find_by!(email: "cutting@puitei.test"), reason: "Phase 9 sample personal leave")
if sample_leave.new_record?
  sample_leave.assign_attributes(
    branch: branch, leave_type: :personal, starts_on: Date.current + 10.days, ends_on: Date.current + 11.days
  )
  sample_leave.save!
  StaffEvent.record!(staff_member: sample_leave.user, actor: sample_leave.user, event_type: "leave_requested", details: { leave_request_id: sample_leave.id })
end

sample_shift = WorkShift.find_or_initialize_by(user: User.find_by!(email: "tailor@puitei.test"), notes: "Phase 9 sample workshop shift")
if sample_shift.new_record?
  sample_shift.assign_attributes(
    branch: branch, created_by: User.find_by!(email: "manager@puitei.test"),
    starts_at: 2.days.from_now.change(hour: 9, min: 0), ends_at: 2.days.from_now.change(hour: 17, min: 30),
    location: branch.name
  )
  sample_shift.save!
  StaffEvent.record!(staff_member: sample_shift.user, actor: sample_shift.created_by, event_type: "shift_scheduled", details: { work_shift_id: sample_shift.id })
end

second_shop = Shop.find_or_create_by!(slug: "esther-design-house") do |record|
  record.name = "Esther Design House"
  record.country = "India"
end
second_branch = second_shop.branches.find_or_create_by!(code: "MAIN") do |record|
  record.name = "Esther Main Studio"
  record.locale = "en"
  record.time_zone = "Asia/Kolkata"
end
second_owner = User.find_or_initialize_by(email: "esther@puitei.test")
second_owner.assign_attributes(name: "Esther Owner", role: :owner, branch: second_branch, active: true)
second_owner.password = password if second_owner.new_record?
second_owner.save!
second_shop.memberships.find_or_create_by!(user: second_owner) do |membership|
  membership.assign_attributes(branch: second_branch, role: :owner, active: true, employee_code: second_owner.employee_code,
    joined_on: second_owner.joined_on, pay_basis: second_owner.pay_basis, pay_rate: second_owner.pay_rate, accepted_at: Time.current)
end
second_shop.update!(created_by: second_owner)
esther_customer_seed = [
  [ "Esther Sample Customer", "9862402001", "Aizawl", "en" ],
  [ "Lalnunfeli", "9862402002", "Aizawl", "lus" ],
  [ "Grace Hmingthanzami", "9862402003", "Kolasib", "en" ],
  [ "Ruth Lalrempuii", "9862402004", "Champhai", "lus" ],
  [ "Mami Vanlalhriati", "9862402005", "Aizawl", "lus" ],
  [ "Sonia Rai", "9862402006", "Silchar", "hi" ],
  [ "Lalmuankimi", "9862402007", "Serchhip", "lus" ],
  [ "Deborah Lalthlamuani", "9862402008", "Aizawl", "en" ],
  [ "Rina Chakma", "9862402009", "Lunglei", "hi" ],
  [ "Cindy Zoremmawii", "9862402010", "Aizawl", "lus" ]
]
esther_customer_seed.each do |name, phone, city, language|
  customer = Customer.find_or_initialize_by(branch: second_branch, phone_number: phone)
  customer.assign_attributes(full_name: name, city: city, preferred_language: language, gender: :female)
  customer.save!
end

design_palettes = [
  [ "F5EFE6", "1D2939", "B38B4D" ], [ "EEF2F4", "344054", "98A2B3" ],
  [ "F8EDEB", "7A271A", "D6A48F" ], [ "EEF4ED", "355E3B", "A6B985" ],
  [ "F4F0F8", "4A3663", "B6A0CF" ], [ "F9F3E5", "693D12", "D4A72C" ],
  [ "EDF3F7", "17324D", "7CA1BF" ], [ "F6EEF2", "6B2948", "C58AA6" ]
]

puitei_design_seed = [
  [ "Pearl-edge Wedding Blouse", "blouse", "Ivory", "Silk", "bridal, pearl, neckline", "Wedding" ],
  [ "Modern Mizo Puan Gown", "gown", "Crimson", "Puan weave", "mizo, premium, woven", "Celebration" ],
  [ "Gold Vine Church Dress", "dress", "Forest green", "Cotton satin", "church, embroidery, modest", "Church" ],
  [ "High-neck Velvet Blouse", "blouse", "Midnight navy", "Velvet", "neckline, evening, premium", "Reception" ],
  [ "Soft Pleat Summer Kurti", "kurti", "Sage", "Linen blend", "summer, minimal, daywear", "Everyday" ],
  [ "Scalloped Sleeve Blouse", "blouse", "Rose", "Raw silk", "sleeve, bridal, scallop", "Wedding" ],
  [ "Ivory Cathedral Gown", "gown", "Ivory", "Organza", "bridal, gown, formal", "Wedding" ],
  [ "Handwork Maroon Lehenga", "lehenga", "Maroon", "Silk", "bridal, embroidery, handwork", "Celebration" ],
  [ "Structured School Blazer", "school_uniform", "Navy", "Twill", "uniform, structured, school", "School" ],
  [ "Mandarin Collar Church Dress", "dress", "Dusty blue", "Crepe", "church, collar, modest", "Church" ],
  [ "Beaded Boat-neck Blouse", "blouse", "Champagne", "Silk", "neckline, beadwork, bridal", "Wedding" ],
  [ "Panelled Puan Kurti", "kurti", "Black", "Puan weave", "mizo, modern, panelled", "Cultural" ],
  [ "Minimal Linen Shirt", "shirt", "Stone", "Linen", "minimal, menswear, summer", "Everyday" ],
  [ "Embroidered Bishop Sleeve", "blouse", "Plum", "Chiffon", "sleeve, embroidery, evening", "Celebration" ],
  [ "Tea-length Garden Dress", "dress", "Blush", "Cotton voile", "summer, floral, daywear", "Garden party" ],
  [ "Premium Satin Evening Gown", "gown", "Emerald", "Satin", "premium, gown, evening", "Reception" ],
  [ "Contrast Piping Kurti", "kurti", "Mustard", "Cotton", "modern, piping, everyday", "Everyday" ],
  [ "Classic Pleated Skirt", "skirt", "Charcoal", "Wool blend", "classic, pleated, workwear", "Office" ],
  [ "Zardozi Bridal Blouse", "blouse", "Ruby", "Silk", "bridal, embroidery, zardozi", "Wedding" ],
  [ "Relaxed Resort Dress", "dress", "Coral", "Linen blend", "summer, resort, relaxed", "Holiday" ],
  [ "Tapered Formal Trouser", "trouser", "Graphite", "Suiting", "formal, tailored, menswear", "Office" ],
  [ "Contemporary Mizo Jacket", "suit", "Indigo", "Puan weave", "mizo, modern, structured", "Cultural" ],
  [ "Crystal Neckline Gown", "gown", "Silver", "Tulle", "premium, crystal, neckline", "Reception" ],
  [ "New Season Wrap Dress", "dress", "Terracotta", "Crepe", "new season, wrap, modern", "Everyday" ]
]

puitei_owner = User.find_by!(email: "owner@puitei.test")
puitei_designs = puitei_design_seed.each_with_index.map do |(title, garment_type, colour, fabric, tags, occasion), index|
  seed_design(
    shop: shop, actor: puitei_owner, palette: design_palettes[index % design_palettes.length], variation: index,
    attributes: {
      title: title, garment_type: garment_type, colour_family: colour, fabric_type: fabric,
      tag_list: tags, occasion: occasion, visibility: (index % 5 == 0 ? :customer_shareable : :private),
      source_type: :original, description: "Curated Puitei Chhakchhuak reference for #{occasion.downcase} tailoring.",
      estimated_price: 1800 + (index * 175), estimated_minutes: 180 + (index % 6) * 60, active: true
    }
  )
end

bridal_collection = seed_design_collection(shop: shop, actor: puitei_owner, name: "Bridal Collection", description: "Ceremony-ready blouses, gowns and lehenga references.", visibility: :staff_visible, designs: puitei_designs.values_at(0, 5, 6, 7, 10, 18, 22), position: 1)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Blouse Neck Designs", description: "Refined neckline and sleeve references for blouse consultations.", visibility: :staff_visible, designs: puitei_designs.values_at(0, 3, 5, 10, 13, 18), position: 2)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Church Dresses", description: "Modest silhouettes with polished construction details.", visibility: :staff_visible, designs: puitei_designs.values_at(2, 9, 14), position: 3)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Modern Mizo Designs", description: "Contemporary garments using Mizo-inspired woven details.", visibility: :customer_shareable, designs: puitei_designs.values_at(1, 11, 21), position: 4)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Embroidery Ideas", description: "Handwork, beadwork and embroidery references for premium finishes.", visibility: :private, designs: puitei_designs.values_at(2, 7, 10, 13, 18, 22), position: 5)
seed_design_collection(shop: shop, actor: puitei_owner, name: "New Season", description: "Fresh silhouettes for upcoming customer consultations.", visibility: :staff_visible, designs: puitei_designs.last(6), position: 6)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Consultation Drafts", description: "An intentionally empty workspace for upcoming consultations.", visibility: :private, designs: [], position: 7)
seed_design_collection(shop: shop, actor: puitei_owner, name: "Archived Seasonal Ideas", description: "Archived references retained for studio history.", visibility: :private, designs: puitei_designs.values_at(14, 16, 19), position: 8, active: false, legacy_names: [ "Past Season" ])
bridal_collection.update!(cover_design: puitei_designs[6]) unless bridal_collection.cover_design_id == puitei_designs[6].id

puitei_designs.values_at(0, 5, 10).each_with_index do |design, index|
  selection = shop.design_selections.active.find_or_initialize_by(customer: customers.first, design: design)
  selection.assign_attributes(
    selected_by: puitei_owner, status: index == 0 ? :approved : :shortlisted,
    customer_note: index == 0 ? "Preferred neckline and pearl finish." : "Keep as an alternate consultation reference.",
    selected_at: index.days.ago
  )
  selection.save!
end

shop.design_favourites.find_or_create_by!(user: puitei_owner, design: puitei_designs.first)

demo_share_token = "puitei-demo-preview"
demo_share = shop.design_shares.find_or_initialize_by(title: "Puitei Chhakchhuak consultation shortlist", customer: customers.first)
demo_share.assign_attributes(
  created_by: puitei_owner, token_digest: DesignShare.digest(demo_share_token), token_hint: demo_share_token.last(6),
  expires_at: 30.days.from_now, allow_feedback: true,
  message: "Please review these workshop references before your next fitting."
)
demo_share.save!
puitei_designs.values_at(0, 5, 10).each_with_index do |design, position|
  demo_share.design_share_items.find_or_create_by!(design: design) do |item|
    item.assign_attributes(shop: shop, position: position)
  end
end

esther_design_seed = [
  [ "Rose Gold Reception Gown", "gown", "Rose gold", "Satin", "premium, reception" ],
  [ "Lace Yoke Church Dress", "dress", "Ivory", "Crepe", "church, lace" ],
  [ "Classic Round-neck Blouse", "blouse", "Teal", "Silk", "blouse, classic" ],
  [ "Summer Block-print Kurti", "kurti", "Indigo", "Cotton", "summer, print" ],
  [ "Pearl Cuff Evening Blouse", "blouse", "Black", "Velvet", "pearl, evening" ],
  [ "Soft Tulle Bridal Gown", "gown", "Ivory", "Tulle", "bridal, premium" ],
  [ "Modern Puan Midi Dress", "dress", "Maroon", "Puan weave", "mizo, modern" ],
  [ "Pleated Office Skirt", "skirt", "Navy", "Suiting", "office, classic" ],
  [ "Embroidered Festive Kurti", "kurti", "Mustard", "Silk", "embroidery, festive" ],
  [ "Structured Linen Shirt", "shirt", "White", "Linen", "menswear, minimal" ],
  [ "Scallop Hem Party Dress", "dress", "Plum", "Organza", "party, scallop" ],
  [ "Crystal Strap Premium Gown", "gown", "Emerald", "Satin", "crystal, premium" ]
]
esther_designs = esther_design_seed.each_with_index.map do |(title, garment_type, colour, fabric, tags), index|
  seed_design(
    shop: second_shop, actor: second_owner, palette: design_palettes[(index + 3) % design_palettes.length], variation: index + 30,
    attributes: {
      title: title, garment_type: garment_type, colour_family: colour, fabric_type: fabric,
      tag_list: tags, occasion: "Consultation", visibility: :private, source_type: :original,
      description: "Private Esther Design House studio reference.", estimated_price: 2200 + index * 200,
      estimated_minutes: 240 + (index % 5) * 60, active: true
    }
  )
end
esther_bridal = seed_design_collection(shop: second_shop, actor: second_owner, name: "Bridal Collection", description: "Premium bridal and reception references.", visibility: :private, designs: esther_designs.values_at(0, 5, 11), position: 1, legacy_names: [ "Esther Bridal Edit" ])
seed_design_collection(shop: second_shop, actor: second_owner, name: "Church Dresses", description: "Elegant occasion dresses with modest silhouettes.", visibility: :staff_visible, designs: esther_designs.values_at(1, 6, 10), position: 2, legacy_names: [ "Church & Occasion" ])
seed_design_collection(shop: second_shop, actor: second_owner, name: "Everyday Studio", description: "Practical blouse, kurti and workwear references.", visibility: :staff_visible, designs: esther_designs.values_at(2, 3, 7, 8, 9), position: 3)
seed_design_collection(shop: second_shop, actor: second_owner, name: "Esther Past Edit", description: "Archived seasonal references kept separate from active work.", visibility: :private, designs: esther_designs.values_at(4, 10), position: 4, active: false)
esther_bridal.update!(cover_design: esther_designs[5]) unless esther_bridal.cover_design_id == esther_designs[5].id

esther_customer = second_shop.customers.active.order(:id).first
esther_designs.first(3).each_with_index do |design, index|
  selection = second_shop.design_selections.active.find_or_initialize_by(customer: esther_customer, design: design)
  selection.assign_attributes(selected_by: second_owner, status: index.zero? ? :approved : :interested, selected_at: index.days.ago)
  selection.save!
end

puts "Seeded #{Shop.count} shops, #{Branch.count} branches, and #{Membership.count} memberships."
puts "Seeded #{Customer.count} customers, #{MeasurementTemplate.count} measurement templates, and #{Measurement.count} measurement versions."
puts "Seeded #{Order.count} orders and #{OrderItem.count} order items."
puts "Seeded #{ProductionTask.count} production tasks and #{ProductionEvent.count} production events."
puts "Seeded #{Payment.count} payments."
puts "Seeded #{InventoryItem.count} inventory items and #{StockMovement.count} stock movements."
puts "Seeded #{Delivery.count} deliveries with #{Order.confirmed.count} confirmed orders in active workflows."
puts "Seeded #{Expense.count} expenses with #{Expense.pending_review.count} pending approval."
puts "Seeded #{AttendanceRecord.count} attendance records, #{LeaveRequest.count} leave requests, and #{WorkShift.count} work shifts."
puts "Seeded #{Design.count} designs across #{DesignCollection.count} design collections."
puts "Seeded #{DesignSelection.count} customer design selections and #{DesignShare.count} secure design shares."
puts "Development sample accounts created with the supplied SEED_PASSWORD." if Rails.env.development?
end

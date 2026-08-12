module ApplicationHelper
  ICON_PATHS = {
    "dashboard" => [ "M4 4h6v6H4z", "M14 4h6v6h-6z", "M4 14h6v6H4z", "M14 14h6v6h-6z" ],
    "customers" => [ "M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2", "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8", "M22 21v-2a4 4 0 0 0-3-3.87", "M16 3.13a4 4 0 0 1 0 7.75" ],
    "ruler" => [ "M21.3 8.7 8.7 21.3a2.4 2.4 0 0 1-3.4 0l-2.6-2.6a2.4 2.4 0 0 1 0-3.4L15.3 2.7a2.4 2.4 0 0 1 3.4 0l2.6 2.6a2.4 2.4 0 0 1 0 3.4Z", "m7.5 16.5 2 2", "m10.5 13.5 2 2", "m13.5 10.5 2 2", "m16.5 7.5 2 2" ],
    "orders" => [ "M9 5h6", "M9 3h6v4H9z", "M6 5H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-1", "M8 12h8", "M8 16h5" ],
    "production" => [ "M6 7a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z", "M6 23a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z", "m8.6 8.6 12.8 12.8", "M14.5 14.5 21.4 7.6", "M8.6 15.4 12 12" ],
    "payments" => [ "M4 5h16a2 2 0 0 1 2 2v12H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z", "M16 13h6", "M16 13a2 2 0 1 0 0 4h6v-4Z", "M6 9h8" ],
    "inventory" => [ "M21 8v13H3V8", "M1 3h22v5H1z", "M10 12h4" ],
    "delivery" => [ "M3 7h11v10H3z", "M14 10h4l3 3v4h-7z", "M7 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z", "M18 20a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z" ],
    "expenses" => [ "M6 2h12v20l-3-2-3 2-3-2-3 2Z", "M9 7h6", "M9 11h6", "M9 15h3" ],
    "staff" => [ "M4 4h16v16H4z", "M9 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z", "M6 17a3 3 0 0 1 6 0", "M15 8h2", "M15 12h2" ],
    "reports" => [ "M4 20V10", "M10 20V4", "M16 20v-7", "M22 20H2" ],
    "notifications" => [ "M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9", "M13.73 21a2 2 0 0 1-3.46 0" ],
    "settings" => [ "M12 15.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z", "M19.4 15a1.7 1.7 0 0 0 .34 1.88l.06.06-2.12 3.67-.08-.02a1.7 1.7 0 0 0-1.8-.43l-.61.36a1.7 1.7 0 0 0-.8 1.65V22H9.61v-.09a1.7 1.7 0 0 0-.8-1.65l-.61-.36a1.7 1.7 0 0 0-1.8.43l-.08.02-2.12-3.67.06-.06A1.7 1.7 0 0 0 4.6 15l-.62-1.07a1.7 1.7 0 0 0-1.54-.85H2V8.92h.44a1.7 1.7 0 0 0 1.54-.85L4.6 7a1.7 1.7 0 0 0-.34-1.88l-.06-.06 2.12-3.67.08.02a1.7 1.7 0 0 0 1.8.43l.61-.36a1.7 1.7 0 0 0 .8-1.65V0h4.78v.09a1.7 1.7 0 0 0 .8 1.65l.61.36a1.7 1.7 0 0 0 1.8-.43l.08-.02 2.12 3.67-.06.06A1.7 1.7 0 0 0 19.4 7l.62 1.07a1.7 1.7 0 0 0 1.54.85H22v4.16h-.44a1.7 1.7 0 0 0-1.54.85Z" ],
    "search" => [ "M21 21l-4.35-4.35", "M11 19a8 8 0 1 1 0-16 8 8 0 0 1 0 16Z" ],
    "plus" => [ "M12 5v14", "M5 12h14" ],
    "more" => [ "M5 12h.01", "M12 12h.01", "M19 12h.01" ],
    "calendar" => [ "M6 2v4", "M18 2v4", "M3 9h18", "M5 4h14a2 2 0 0 1 2 2v15H3V6a2 2 0 0 1 2-2Z" ],
    "clock" => [ "M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20Z", "M12 6v6l4 2" ],
    "check" => [ "m5 12 4 4L19 6" ],
    "warning" => [ "M10.3 3.7 1.8 18.5A2 2 0 0 0 3.5 21h17a2 2 0 0 0 1.7-2.5L13.7 3.7a2 2 0 0 0-3.4 0Z", "M12 9v4", "M12 17h.01" ],
    "arrow-right" => [ "M5 12h14", "m13 6 6 6-6 6" ],
    "arrow-left" => [ "M19 12H5", "m11 18-6-6 6-6" ],
    "chevron-right" => [ "m9 18 6-6-6-6" ],
    "chevron-down" => [ "m6 9 6 6 6-6" ],
    "x" => [ "M18 6 6 18", "M6 6l12 12" ],
    "building" => [ "M3 21h18", "M6 21V3h12v18", "M9 7h2", "M13 7h2", "M9 11h2", "M13 11h2", "M10 21v-5h4v5" ],
    "logout" => [ "M10 17l5-5-5-5", "M15 12H3", "M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" ],
    "needle" => [ "M20.7 3.3a2.4 2.4 0 0 0-3.4 0L5 15.6 3 21l5.4-2 12.3-12.3a2.4 2.4 0 0 0 0-3.4Z", "m14 6 4 4", "M5 15.6 8.4 19" ],
    "sparkles" => [ "m12 3-1 3-3 1 3 1 1 3 1-3 3-1-3-1Z", "m19 14-.7 2.3L16 17l2.3.7L19 20l.7-2.3L22 17l-2.3-.7Z", "m5 13-.7 1.3L3 15l1.3.7L5 17l.7-1.3L7 15l-1.3-.7Z" ],
    "designs" => [ "M4 3h16a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z", "m2 17 5-5 4 4 3-3 8 8", "M16.5 8.5h.01" ],
    "user" => [ "M20 21a8 8 0 0 0-16 0", "M12 13a5 5 0 1 0 0-10 5 5 0 0 0 0 10Z" ]
  }.freeze

  STATUS_VARIANTS = {
    "draft" => "neutral", "pending" => "neutral", "unpaid" => "warning",
    "confirmed" => "info", "in_progress" => "info", "partial" => "warning",
    "completed" => "success", "paid" => "success", "approved" => "success", "ready" => "success", "delivered" => "success",
    "skipped" => "neutral", "cancelled" => "danger", "void" => "danger", "overdue" => "danger"
  }.freeze

  MEASUREMENT_FIELD_GROUPS = {
    "lower_body" => %w[trouser_length inseam rise thigh knee bottom bottom_opening outseam calf ankle],
    "neck_arm" => %w[neck front_neck_depth back_neck_depth armhole sleeve_length sleeve_round cuff bicep],
    "length" => %w[length garment_length blouse_length waist_length shirt_length kurti_length dress_length gown_length],
    "upper_body" => %w[bust chest waist hip seat shoulder across_back across_front back_width front_width]
  }.freeze

  def unread_notification_count
    current_user.notifications.unread.count
  end

  def recent_notifications(limit: 5)
    current_user.notifications.recent_first.limit(limit)
  end

  def money(amount, currency = "INR")
    number_to_currency(amount, unit: "#{currency} ", precision: 2)
  end

  def stock_quantity(amount, unit = nil)
    value = number_with_precision(amount, precision: 3, strip_insignificant_zeros: true)
    unit.present? ? "#{value} #{t("inventory.units.#{unit}", count: amount)}" : value
  end

  def inventory_stock_badge(item)
    variants = { "in_stock" => "success", "low_stock" => "warning", "out_of_stock" => "danger" }
    status_badge(item.stock_status, label: t("inventory.stock_statuses.#{item.stock_status}"), variant: variants.fetch(item.stock_status))
  end

  def stock_movement_badge(movement)
    variant = if movement.stock_in? || movement.adjustment_in?
      "success"
    elsif movement.reservation? || movement.release?
      "info"
    elsif movement.wastage?
      "danger"
    else
      "warning"
    end
    status_badge(movement.movement_type, label: t("inventory.movement_types.#{movement.movement_type}"), variant: variant)
  end

  def expense_status_badge(expense)
    if expense.voided?
      status_badge("void", label: t("expenses.statuses.voided"), variant: "danger")
    elsif expense.approval_approved?
      status_badge("approved", label: t("expenses.statuses.approved"), variant: "success")
    else
      status_badge("pending", label: t("expenses.statuses.pending"), variant: "warning")
    end
  end

  def leave_status_badge(request)
    variants = { "pending" => "warning", "approved" => "success", "rejected" => "danger", "cancelled" => "neutral" }
    status_badge(request.status, label: t("leave_requests.statuses.#{request.status}"), variant: variants.fetch(request.status))
  end

  def ui_icon(name, size: 20, class_name: nil, label: nil)
    paths = ICON_PATHS.fetch(name.to_s) { raise ArgumentError, "Unknown icon: #{name}" }
    attributes = {
      viewBox: "0 0 24 24", width: size, height: size, fill: "none", stroke: "currentColor",
      "stroke-width": 1.75, "stroke-linecap": "round", "stroke-linejoin": "round",
      class: [ "shrink-0", class_name ].compact.join(" ")
    }
    attributes[label ? :role : "aria-hidden"] = label ? "img" : "true"

    tag.svg(**attributes) do
      safe_join([ (tag.title(label) if label), *paths.map { |path| tag.path(d: path) } ].compact)
    end
  end

  def status_badge(status, label: nil, variant: nil)
    key = status.to_s
    variant ||= STATUS_VARIANTS.fetch(key, "neutral")
    text = label || key.humanize
    tag.span(text, class: "status-badge status-#{variant}", data: { status: key })
  end

  def initials_for(name)
    name.to_s.split.filter_map { |part| part[0] }.first(2).join.upcase
  end

  def nav_active?(*names)
    controller_name.in?(names.flatten.map(&:to_s))
  end

  SECTION_LABELS = {
    "dashboard" => %w[dashboard],
    "orders" => %w[orders],
    "customers" => %w[customers],
    "measurements" => %w[measurement_profiles measurements],
    "designs" => %w[designs design_collections design_collection_items design_favourites design_selections design_shares],
    "production" => %w[productions production_tasks],
    "payments" => %w[payments],
    "inventory" => %w[inventory_items stock_movements],
    "expenses" => %w[expenses],
    "deliveries" => %w[deliveries],
    "reports" => %w[reports],
    "staff" => %w[staff attendance_records leave_requests work_shifts staff_invitations],
    "settings" => %w[payment_settings onboardings]
  }.freeze

  def current_section_title
    key = SECTION_LABELS.find { |_label, controllers| controller_name.in?(controllers) }&.first
    key ? t("navigation.#{key}") : controller_name.humanize
  end

  def time_greeting(time = Time.current)
    case time.hour
    when 5...12 then t("dashboard.greetings.morning")
    when 12...17 then t("dashboard.greetings.afternoon")
    else t("dashboard.greetings.evening")
    end
  end

  def filter_date_range_label(from, to, fallback:)
    from_date = Date.iso8601(from) if from.present?
    to_date = Date.iso8601(to) if to.present?
    return fallback unless from_date || to_date
    return l(from_date, format: :short) if from_date == to_date

    [ (l(from_date, format: :short) if from_date), (l(to_date, format: :short) if to_date) ].compact.join(" – ")
  rescue Date::Error
    fallback
  end

  def order_status_badge(order)
    if order.delivered?
      status_badge("delivered", label: t("orders.statuses.delivered"), variant: "success")
    elsif order.cancelled?
      status_badge("cancelled", label: t("orders.statuses.cancelled"), variant: "danger")
    elsif order.draft?
      status_badge("draft", label: t("orders.statuses.draft"), variant: "neutral")
    elsif order.production_complete?
      status_badge("ready", label: t("dashboard.order_states.ready"), variant: "success")
    elsif order.order_items.any? { |item| item.production_tasks.any?(&:in_progress?) }
      status_badge("in_progress", label: t("dashboard.order_states.in_production"), variant: "info")
    else
      status_badge("confirmed", label: t("orders.statuses.confirmed"), variant: "info")
    end
  end

  def order_display_total(order)
    order.billable? ? order.total_amount : order.estimated_subtotal
  end

  def order_delivery_state(order)
    return "delivered" if order.delivered?
    return "cancelled" if order.cancelled?
    return "overdue" if order.delivery_date < Date.current
    return "due_soon" if order.delivery_date <= 7.days.from_now.to_date

    "upcoming"
  end

  def order_delivery_label(order)
    case order_delivery_state(order)
    when "delivered" then t("orders.delivery_states.delivered")
    when "cancelled" then t("orders.delivery_states.cancelled")
    when "overdue" then t("orders.delivery_states.overdue", count: (Date.current - order.delivery_date).to_i)
    when "due_soon" then t("orders.delivery_states.due_soon", count: (order.delivery_date - Date.current).to_i)
    else t("orders.delivery_states.upcoming", count: (order.delivery_date - Date.current).to_i)
    end
  end

  def grouped_measurement_fields(template)
    template.measurement_fields.group_by { |field| measurement_field_group(field.key) }
  end

  def measurement_field_group(key)
    MEASUREMENT_FIELD_GROUPS.each { |group, keys| return group if keys.include?(key.to_s) }
    "other"
  end

  def measurement_value_changes(measurement, previous_measurement)
    return [] unless previous_measurement

    fields_by_key = measurement.measurement_template.measurement_fields.index_by(&:key)
    (measurement.values.keys | previous_measurement.values.keys).filter_map do |key|
      current = measurement.values[key]
      previous = previous_measurement.values[key]
      next if current == previous

      { key: key, label: fields_by_key[key]&.label || key.humanize, previous: previous, current: current }
    end
  end
end

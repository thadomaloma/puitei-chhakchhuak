module Schedule
  Entry = Data.define(:type, :date, :order, :overdue) do
    def fitting?
      type == :fitting
    end

    def delivery?
      type == :delivery
    end

    def customer
      order.customer
    end

    def days_overdue
      overdue ? (Date.current - date).to_i : 0
    end
  end
end

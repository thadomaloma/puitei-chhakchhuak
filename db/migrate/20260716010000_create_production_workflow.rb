class CreateProductionWorkflow < ActiveRecord::Migration[8.1]
  def up
    add_column :order_items, :requires_embroidery, :boolean, null: false, default: false

    create_table :production_tasks do |t|
      t.references :order_item, null: false, foreign_key: true
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.references :completed_by, foreign_key: { to_table: :users }
      t.integer :stage, null: false
      t.integer :status, null: false, default: 0
      t.integer :position, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.text :notes
      t.timestamps
    end

    add_index :production_tasks, [ :order_item_id, :stage ], unique: true
    add_index :production_tasks, [ :status, :stage, :assigned_to_id ], name: "index_production_tasks_queue"
    add_check_constraint :production_tasks, "stage >= 0 AND stage <= 3", name: "production_tasks_stage_range"
    add_check_constraint :production_tasks, "status >= 0 AND status <= 3", name: "production_tasks_status_range"
    add_check_constraint :production_tasks, "position >= 0", name: "production_tasks_position_positive"
    add_check_constraint :production_tasks, "status != 1 OR started_at IS NOT NULL", name: "production_tasks_started_at"
    add_check_constraint :production_tasks, "status NOT IN (2, 3) OR completed_at IS NOT NULL", name: "production_tasks_completed_at"

    create_table :production_events do |t|
      t.references :production_task, null: false, foreign_key: true
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status
      t.text :notes
      t.datetime :created_at, null: false
    end

    add_index :production_events, [ :production_task_id, :created_at ]
    add_check_constraint :production_events,
      "event_type IN ('claimed', 'assigned', 'started', 'completed', 'skipped', 'reopened')",
      name: "production_events_type"

    execute <<~SQL.squish
      INSERT INTO production_tasks (order_item_id, stage, status, position, created_at, updated_at)
      SELECT order_items.id, stages.stage, 0, stages.position, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM order_items
      INNER JOIN orders ON orders.id = order_items.order_id
      CROSS JOIN (VALUES (0, 0), (2, 1), (3, 2)) AS stages(stage, position)
      WHERE orders.status = 1
    SQL
  end

  def down
    drop_table :production_events
    drop_table :production_tasks
    remove_column :order_items, :requires_embroidery
  end
end

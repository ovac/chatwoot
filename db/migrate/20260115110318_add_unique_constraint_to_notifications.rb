class AddUniqueConstraintToNotifications < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_index :notifications,
              [:user_id, :notification_type, :primary_actor_id, :secondary_actor_id],
              unique: true,
              algorithm: :concurrently,
              name: 'idx_notifications_unique_per_message'
  end
end

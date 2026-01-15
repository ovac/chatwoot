class AddUniqueConstraintToNotifications < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    # Clean up duplicates before creating unique indexes
    cleanup_duplicates_without_secondary_actor
    cleanup_duplicates_with_secondary_actor

    # Enforce uniqueness for notifications without a secondary actor
    add_index :notifications,
              %i[user_id notification_type primary_actor_id],
              unique: true,
              where: 'secondary_actor_id IS NULL',
              algorithm: :concurrently,
              name: 'idx_notifications_unique_without_secondary_actor'

    # Enforce uniqueness for notifications with a secondary actor
    add_index :notifications,
              %i[user_id notification_type primary_actor_id secondary_actor_id],
              unique: true,
              where: 'secondary_actor_id IS NOT NULL',
              algorithm: :concurrently,
              name: 'idx_notifications_unique_with_secondary_actor'
  end

  private

  def cleanup_duplicates_without_secondary_actor
    # Delete duplicates for notifications without secondary_actor_id
    # Keep only the notification with the highest id for each duplicate group
    duplicate_groups = Notification.where(secondary_actor_id: nil)
                                   .group(:user_id, :notification_type, :primary_actor_id)
                                   .having('COUNT(*) > 1')
                                   .pluck(:user_id, :notification_type, :primary_actor_id)

    duplicate_groups.each do |user_id, notification_type, primary_actor_id|
      notifications = Notification.where(
        user_id: user_id,
        notification_type: notification_type,
        primary_actor_id: primary_actor_id,
        secondary_actor_id: nil
      ).order(id: :desc)

      # Keep the first (highest id), delete the rest
      notifications.offset(1).delete_all
    end
  end

  def cleanup_duplicates_with_secondary_actor
    # Delete duplicates for notifications with secondary_actor_id
    # Keep only the notification with the highest id for each duplicate group
    duplicate_groups = Notification.where.not(secondary_actor_id: nil)
                                   .group(:user_id, :notification_type, :primary_actor_id, :secondary_actor_id)
                                   .having('COUNT(*) > 1')
                                   .pluck(:user_id, :notification_type, :primary_actor_id, :secondary_actor_id)

    duplicate_groups.each do |user_id, notification_type, primary_actor_id, secondary_actor_id|
      notifications = Notification.where(
        user_id: user_id,
        notification_type: notification_type,
        primary_actor_id: primary_actor_id,
        secondary_actor_id: secondary_actor_id
      ).order(id: :desc)

      # Keep the first (highest id), delete the rest
      notifications.offset(1).delete_all
    end
  end

  def down
    if index_exists?(:notifications, name: 'idx_notifications_unique_with_secondary_actor')
      remove_index :notifications, name: 'idx_notifications_unique_with_secondary_actor'
    end

    return unless index_exists?(:notifications, name: 'idx_notifications_unique_without_secondary_actor')

    remove_index :notifications, name: 'idx_notifications_unique_without_secondary_actor'
  end
end

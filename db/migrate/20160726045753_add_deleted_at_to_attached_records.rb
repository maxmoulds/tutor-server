class AddDeletedAtToAttachedRecords < ActiveRecord::Migration
  def change
    add_column :salesforce_attached_records, :deleted_at, :datetime
  end
end

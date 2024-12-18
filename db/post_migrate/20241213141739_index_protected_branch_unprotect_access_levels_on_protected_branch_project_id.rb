# frozen_string_literal: true

class IndexProtectedBranchUnprotectAccessLevelsOnProtectedBranchProjectId < Gitlab::Database::Migration[2.2]
  milestone '17.8'
  disable_ddl_transaction!

  INDEX_NAME = 'i_protected_branch_unprotect_access_levels_protected_branch_pro'

  def up
    add_concurrent_index :protected_branch_unprotect_access_levels, :protected_branch_project_id, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name :protected_branch_unprotect_access_levels, INDEX_NAME
  end
end

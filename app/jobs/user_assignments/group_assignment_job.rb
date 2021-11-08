# frozen_string_literal: true

module UserAssignments
  class GroupAssignmentJob < ApplicationJob
    queue_as :high_priority

    def perform(team, project, assigned_by)
      @team = team
      @assigned_by = assigned_by

      ActiveRecord::Base.transaction do
        team.users.where.not(id: project.users.pluck(:id)).where.not(id: assigned_by.id).find_each do |user|
          UserAssignment.create!(
            user: user,
            assignable: project,
            user_role: project.group_user_role,
            assigned_by: @assigned_by,
            assigned: :automatically
          )
          # make sure all related experiments and my modules are assigned
          UserAssignments::PropagateAssignmentJob.perform_later(
            project,
            user,
            project.group_user_role,
            @assigned_by
          )
        end
      end
    end
  end
end
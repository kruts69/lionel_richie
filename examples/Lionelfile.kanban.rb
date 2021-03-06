Lionel.export do
  B { id }

  # Card link
  C { link(name.gsub(/^\[.*\]\s*/, "")) }

  # Ready date
  D do |export|
    ready_action = first_action do |a|
      (a.create? && a.board_id == export.trello_board_id) || a.moved_to?("Ready")
    end
    format_date(ready_action.date) if ready_action
  end

  # In Progress date
  E { date_moved_to("In Progress") }

  # Code Review date
  F { date_moved_to("Code Review") }

  # Review date
  G { date_moved_to("Review") }

  # Deploy date
  H { date_moved_to("Deploy") }

  # Completed date
  I { date_moved_to("Completed") }

  # Type
  J { type }

  # Project
  K { project }

  # Estimate
  L { estimate }

  # Due Date
  M { due_date }
end

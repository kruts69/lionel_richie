module Lionel
  class Export

    attr_reader :options
    def initialize(options = {})
      @options = options
      configure
    end

    def google_doc_id
      ENV['GOOGLE_DOC_ID']
    end

    def trello_board_id
      ENV['TRELLO_BOARD_ID']
    end

    def google_token
      ENV['GOOGLE_TOKEN']
    end

    def trello_key
      ENV['TRELLO_KEY']
    end

    def trello_token
      ENV['TRELLO_TOKEN']
    end

    def configure
      Trello.configure do |c|
        c.developer_public_key  = trello_key
        c.member_token          = trello_token
      end
    end

    def board
      @board ||= Trello::Board.find(trello_board_id)
    end

    def cards
      cards ||= [].tap do |c|
        # iterate over active lists rather
        # than retrieving all historical cards
        board.lists.each do |list|
          list.cards.each do |card|
            c << card
          end
        end
      end.map { |c| Lionel::ProxyCard.new(c) }
    end

    def google_doc
      @google_doc ||= begin
        session = GoogleDrive.login_with_oauth(google_token)
        session.spreadsheet_by_key(google_doc_id)
      end
    end

    def worksheet
      @worksheet ||= Lionel::ProxyWorksheet.new(google_doc.worksheets[0])
    end

    def authenticate
      cards && worksheet
    end

    def load
      puts "Exporting trello board '#{board.name}' (#{trello_board_id}) to " + "google doc #{google_doc.title} (#{google_doc_id})"

      start_row = 2
      rows = worksheet.size

      card_rows = {}

      # Find existing rows for current cards
      (start_row..rows).each do |row|
        cell_id = worksheet["B",row]
        next unless cell_id.present?
        card = cards.find { |c| c.id == cell_id }
        next unless card.present?
        card_rows[row] = card
      end

      # Set available rows for new cards
      new_cards = cards - card_rows.values
      new_cards.each_with_index do |card, i|
        row = rows + i + 1
        card_rows[row] = card
      end

      card_rows.each do |row, card|
        Timeout.timeout(5) { sync_row(row, card) }
      end
    end

    def save
      worksheet.save
    end

    def rows
      worksheet.rows
    end

    def sync_row(row, card)
      puts "row[#{row}] : #{card.name}"

      worksheet["B",row] = card.id

      # Card link
      worksheet["C",row] = card.link

      # Ready date
      ready_action = card.first_action do |a|
        (a.create? && a.board_id == trello_board_id) || a.moved_to?("Ready")
      end
      worksheet["D",row] = card.format_date(ready_action.date) if ready_action

      # In Progress date
      worksheet["E",row] = card.date_moved_to("In Progress")

      # Code Review date
      worksheet["F",row] = card.date_moved_to("Code Review")

      # Review date
      worksheet["G",row] = card.date_moved_to("Review")

      # Deploy date
      worksheet["H",row] = card.date_moved_to("Deploy")

      # Completed date
      worksheet["I",row] = card.date_moved_to("Completed")

      # Type
      worksheet["J",row] = card.type

      # Project
      worksheet["K",row] = card.project

      # Estimate
      worksheet["L",row] = card.estimate

      # Due Date
      worksheet["M",row] = card.due_date

    rescue Trello::Error => e
      puts e.inspect
      puts card.inspect
    end

  end
end
module Tasks
  module PerformanceReport
    class ExportCcXlsx

      def self.call(course_name:, report:, filename:, options: {})
        filename = "#{filename}.xlsx" unless filename.ends_with?(".xlsx")
        export = new(course_name: course_name, report: report, filepath: filename, options: options)
        export.create
        filename
      end

      # So can be called like other exporters
      def self.[](profile:, report:, filename:, options: {})
        call(course_name: profile.name, report: report, filename: filename, options: options)
      end

      def initialize(course_name:, report:, filepath:, options:)
        @course_name = course_name
        @report = report
        @filepath = filepath
        @helper = XlsxHelper.new
        @options = options
        @eq = options[:stringify_formulas] ? "" : "="
      end

      def create
        @package = Axlsx::Package.new
        @helper.standard_package_settings(@package)

        setup_styles
        write_data_worksheets
        make_first_sheet_active
        save
      end

      protected

      def style!(hash) # TODO move into a helper
        @styles ||= {}

        @styles[hash] ||= begin
          # TODO normalize incoming hash and see if it has been stored already, if
          # so save it again with the non-normalized hash

          style = nil
          @package.workbook.styles{|s| style = s.add_style(hash.dup)}
          style
        end
      end

      def setup_styles
        @package.workbook.styles do |s|
          @title = s.add_style sz: 16
          @course_section = s.add_style sz: 14
          @bold = s.add_style b: true
          @italic = s.add_style i: true
          @pct = s.add_style num_fmt: Axlsx::NUM_FMT_PERCENT
          @italic_pct = s.add_style num_fmt: Axlsx::NUM_FMT_PERCENT, i: true
          @bold_L = s.add_style b: true, border: {edges: [:left], :color => '000000', :style => :thin}
          @bold_R = s.add_style b: true, border: {edges: [:right], :color => '000000', :style => :thin}
          @bold_T = s.add_style b: true, border: {edges: [:top], :color => '000000', :style => :thin}
          @reading_title = s.add_style b: true,
                                       border: { edges: [:left, :top, :right, :bottom], :color => '000000', :style => :thin},
                                       alignment: {horizontal: :center, wrap_text: true}
          @normal_L = s.add_style border: {edges: [:left], :color => '000000', :style => :thin}
          @count_L = s.add_style border: {edges: [:left], :color => '000000', :style => :thin}, format_code: "#"
          @count = s.add_style format_code: "#"
          @pct_L = s.add_style border: {edges: [:left], :color => '000000', :style => :thin}, num_fmt: Axlsx::NUM_FMT_PERCENT
          @right_R = s.add_style border: {edges: [:right], :color => '000000', :style => :thin}, alignment: {horizontal: :right}
          @date_R = s.add_style border: {edges: [:right], :color => '000000', :style => :thin}, num_fmt: 14
          @average_style = s.add_style b: true, border: { edges: [:top, :bottom], :color => '000000', :style => :thin},
                                       border_top: {style: :medium}, format_code: "#", bg_color: 'F2F2F2'
          @average_R = s.add_style b: true, border: { edges: [:top, :bottom, :right], :color => '000000', :style => :thin},
                                   border_top: {style: :medium}, format_code: "#", bg_color: 'F2F2F2'
          @average_pct = s.add_style b: true,
                                     border: { edges: [:top, :bottom], :color => '000000', :style => :thin},
                                     border_top: {style: :medium},
                                     num_fmt: Axlsx::NUM_FMT_PERCENT, bg_color: 'F2F2F2'
          @average_pct_R = s.add_style b: true,
                                     border: { edges: [:top, :bottom, :right], :color => '000000', :style => :thin},
                                     border_top: {style: :medium},
                                     num_fmt: Axlsx::NUM_FMT_PERCENT, bg_color: 'F2F2F2'
          @average_R = s.add_style b: true, border: { edges: [:top, :bottom, :right], :color => '000000', :style => :thin},
                                 border_right: {style: :thin}, format_code: "#", bg_color: 'F2F2F2', border_top: {style: :medium}
          @average_pct = s.add_style b: true,
                                     border: { edges: [:top, :bottom], :color => '000000', :style => :thin},
                                     num_fmt: Axlsx::NUM_FMT_PERCENT, bg_color: 'F2F2F2', border_top: {style: :medium}
        end
      end

      def write_data_worksheets
        @report.each do |period_report|
          write_period_worksheet(
            report: period_report,
            sheet: new_period_sheet(report: period_report, format: :percents),
            format: :percents
          )

          write_period_worksheet(
            report: period_report,
            sheet: new_period_sheet(report: period_report, format: :counts),
            format: :counts
          )
        end
      end

      def make_first_sheet_active
        @package.workbook.add_view active_tab: 0
      end

      def new_period_sheet(report:, format:)
        suffix = format == :counts ? " - #" : " - %"
        @package.workbook.add_worksheet(
          name: @helper.sanitized_worksheet_name(name: report[:period][:name], suffix: suffix)
        )
      end

      def row_range(offset:, step:, length:, row:)
        length.times.map{|ii| "#{Axlsx::col_ref(offset + ii*step)}#{row}"}.join(',')
      end

      def write_period_worksheet(report:, sheet:, format:)

        num_tasks = report[:data_headings].length # TODO use this more

        # META INFO ROWS

        meta_rows = [
          [["Concept Coach Student Scores", {style: @title}]],
          [[@course_name, {style: @course_section}]],
          [["Exported #{Date.today.strftime("%-m/%-d/%Y")}", {style: @italic}]],
          [[""]],
          [[report[:period][:name], {style: @course_section}]],
          [[""]]
        ]

        # Normally we'd add these rows now to the sheet now; however, we want to set
        # column widths based on the widths of the non-meta rows (the data table).
        # So we hold off on adding these rows until the end of this method so that
        # Axlsx's autowidth calculations can be used.  So that cell references and
        # merged cell locations work out, add placeholder rows here that will be
        # replaced at the end.

        meta_rows.count.times { sheet.add_row }

        # READING TITLE COLUMNS

        reading_title_columns =
          3.times.map{[""]} +
          [["Overall Score (incompletes included)"]] + (format == :counts ? [""] : []) +
          report[:data_headings].map do |data_heading|
            [
              data_heading[:title],
              {
                cols: (format == :counts ? 4 : 3),
                style: @reading_title
              }
            ]
          end

        @helper.add_row(sheet, reading_title_columns)

        # Subheadings

        subheadings = ["","",""]

        if format == :counts
          subheadings.push(["Score",        {style: @bold_L}])
          subheadings.push(["Total Possible",      {style: @bold}])
        else
          subheadings.push("")
        end

        num_tasks.times do
          subheadings.push(["Score",        {style: @bold_L}])
          subheadings.push(["Progress",      {style: @bold}])
          subheadings.push(["Total Possible", {style: @bold}]) if format == :counts
          subheadings.push(["Last Worked",    {style: @bold_R}])
        end

        @helper.add_row(sheet, subheadings)

        # STUDENT INFO COLUMNS

        student_info_columns =
          ["First Name", "Last Name", "Student ID"].map{|text| [text, style: @bold_T]} +
          (format == :counts ? 2 + num_tasks*4 : 1 + num_tasks*3).times.map{""}

        @helper.add_row(sheet, student_info_columns)

        # Have to merge vertically and style merged cells after the fact

        overall_score_merge_range =
          format == :counts ? "D7:E7" : "D7:D9"

        @helper.merge_and_style(sheet, overall_score_merge_range,
          style!(
            b: true,
            bg_color: 'C9F0F8',
            border: { edges: [:left, :top, :right, :bottom], :color => '000000', :style => :thin},
            alignment: {horizontal: :center, vertical: :center, wrap_text: true}
          )
        )

        center_bold_style =
          style!(alignment: {horizontal: :center, vertical: :center, wrap_text: true}, b: true)

        center_bold_R_style = style!(
          b: true, border: {edges: [:right], :color => '000000', :style => :thin},
          alignment: {horizontal: :center, vertical: :center, wrap_text: true})

        center_bold_L_style = style!(
          b: true, border: {edges: [:left], :color => '000000', :style => :thin},
          alignment: {horizontal: :center, vertical: :center, wrap_text: true})

        if format == :counts
          @helper.merge_and_style(sheet, [4,8,4,9], center_bold_L_style)
          @helper.merge_and_style(sheet, [5,8,5,9], center_bold_R_style)

          num_tasks.times.with_index do |ii|
            @helper.merge_and_style(sheet, [6+ii*4,  8,6+ii*4,  9], center_bold_style)
            @helper.merge_and_style(sheet, [6+ii*4+1,8,6+ii*4+1,9], center_bold_style)
            @helper.merge_and_style(sheet, [6+ii*4+2,8,6+ii*4+2,9], center_bold_style)
            @helper.merge_and_style(sheet, [6+ii*4+3,8,6+ii*4+3,9], center_bold_R_style)
          end
        else
          num_tasks.times.with_index do |ii|
            @helper.merge_and_style(sheet, [5+ii*3,  8,5+ii*3,  9], center_bold_style)
            @helper.merge_and_style(sheet, [5+ii*3+1,8,5+ii*3+1,9], center_bold_style)
            @helper.merge_and_style(sheet, [5+ii*3+2,8,5+ii*3+2,9], center_bold_R_style)
          end
        end

        # STUDENT DATA

        first_student_row = sheet.rows.count + 1

        students = report[:students].sort_by{|student| student[:last_name]}

        students.each_with_index do |student, ss|
          student_columns = [
            student[:first_name],
            student[:last_name],
            student[:student_identifier],
          ]

          if format == :counts
            student_columns.push(
              ["#{@eq}IFERROR(SUM(#{row_range(offset:5, step: 4, length: num_tasks, row: first_student_row + ss)}),NA())",
               style: @count_L],
              ["#{@eq}IFERROR(SUM(#{row_range(offset:7, step: 4, length: num_tasks, row: first_student_row + ss)}),NA())",
               style: @count]
            )
          else
            student_columns.push(
              ["#{@eq}IFERROR(AVERAGE(#{row_range(offset:4, step: 3, length: num_tasks, row: first_student_row + ss)}),NA())",
               style: @pct_L]
            )
          end

          student[:data].each_with_index do |data,ss|
            if data
              correct_count = data[:correct_exercise_count]
              completed_count = data[:completed_exercise_count]
              total_count = data[:actual_and_placeholder_exercise_count]

              correct_pct = correct_count * 1.0 / total_count
              completed_pct = completed_count * 1.0 / total_count

              if format == :counts
                student_columns.push([
                  correct_count,
                  {
                    style: @normal_L,
                  }
                ])
                student_columns.push(completed_count)
                student_columns.push(total_count)
              else
                student_columns.push([
                  correct_pct,
                  {
                    style: @pct_L,
                  }
                ])
                student_columns.push([
                  completed_pct,
                  {style: @pct}
                ])
              end
              student_columns.push([data[:last_worked_at], {style: @date_R}])
            else
              if format == :counts
                student_columns.push([0, {style: @normal_L}], 0, report[:data_headings][ss][:average_actual_and_placeholder_exercise_count])
              else
                student_columns.push([0, {style: @pct_L}], [0, {style: @pct}])
              end
              student_columns.push(["Not Started", {style: @right_R}])
            end
          end

          @helper.add_row(sheet, student_columns)
        end

        last_student_row = sheet.rows.count

        # Now that the data is in place, get what Axlsx calculated for the column widths,
        # then set all numerical columns to have a fixed width.

        data_widths = sheet.column_info.map(&:width)
        data_widths[3..-1] = data_widths[3..-1].length.times.map{15}

        # AVERAGE ROW

        average_columns = [
          ["Class Average", {style: @average_style}],
          ["", {style: @average_style}],
          ["", {style: @average_R}]
        ]

        if format == :counts
          average_columns.push(
            ["#{@eq}AVERAGE(D#{first_student_row}:D#{last_student_row})", style: @average_R],
            ["#{@eq}AVERAGE(E#{first_student_row}:E#{last_student_row})", style: @average_R]
          )
        else
          average_columns.push(
            ["#{@eq}AVERAGE(D#{first_student_row}:D#{last_student_row})", style: @average_pct_R]
          )
        end

        num_tasks.times do |index|
          first_column = index * (format == :counts ? 4 : 3) + (format == :counts ? 5 : 4)
          average_style = format == :counts ? @average_style : @average_pct

          correct_range =
            XlsxHelper.cell_ref(row: first_student_row, column: first_column) + ":" +
            XlsxHelper.cell_ref(row: last_student_row, column: first_column)

          completed_range =
            XlsxHelper.cell_ref(row: first_student_row, column: first_column+1) + ":" +
            XlsxHelper.cell_ref(row: last_student_row, column: first_column+1)

          average_columns.push(["#{@eq}AVERAGE(#{correct_range})", {style: average_style}])
          average_columns.push(["#{@eq}AVERAGE(#{completed_range})", {style: average_style}])

          if format == :counts
            total_range =
              XlsxHelper.cell_ref(row: first_student_row, column: first_column+2) + ":" +
              XlsxHelper.cell_ref(row: last_student_row, column: first_column+2)

            average_columns.push(["#{@eq}AVERAGE(#{total_range})", {style: average_style}])
          end

          average_columns.push(["", {style: @average_R}])
        end

        @helper.add_row(sheet, average_columns)

        # Now it is time to add the meta info rows that we skipped at the top of
        # this method.  The trickiness here is that in order to insert the rows
        # we need Axlsx::Row objects.  Per http://stackoverflow.com/a/24144262 one
        # way to do this is to add the rows temporarily to the sheet, delete them
        # immediately (which returns the Row object), then insert them.  We first
        # delete the placeholder rows we added up above. Since we're always
        # inserting in the first row, we reverse the meta rows so they are in the
        # right order.

        meta_rows.count.times { sheet.rows.delete_at(0) }

        meta_rows.reverse.each do |meta_row|
          @helper.add_row(sheet, meta_row)
          sheet.rows.insert 0, sheet.rows.delete_at(sheet.rows.length-1)
        end

        # Now that all data has been added, we set the column widths.

        sheet.column_widths(*data_widths)

      end # end write_period_worksheet

      def save
        success = @package.serialize(@filepath)
        raise(StandardError, "PerformanceReport::ExportCcXlsx failed") unless success
      end

    end
  end
end

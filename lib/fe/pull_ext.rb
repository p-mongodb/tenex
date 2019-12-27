module PullExt

  def jira_project
    ::Mappings.repo_full_name_to_jira_project(repo_full_name)
  end

  def jira_ticket_number
    if @jira_ticket_number_looked_up
      return @jira_ticket_number
    end
    if title =~ /\A((#{jira_project})-(\d+)) /i
      number = $3.to_i
    else
      number = nil
      sources = [body] + comments.map(&:body)
      sources.each do |body|
        if body =~ /#{jira_project}-(\d+)/i
          this_number = $1.to_i
          if number && number != this_number
            raise "Confusing ticket situation"
          end
          number = $1.to_i
        end
      end
    end
    if number.nil?
      if head_ref.to_i.to_s == head_ref
        number = head_ref.to_i
      end
    end
    @jira_ticket_number_looked_up = true
    @jira_ticket_number = number
  end

  def jira_issue_key!
    number = jira_ticket_number
    if number.nil?
      raise "Could not figure out jira ticket number"
    end
    "#{jira_project.upcase}-#{number}"
  end
end

Github::Pull.send(:include, PullExt)

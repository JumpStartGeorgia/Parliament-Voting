class AllDelegate < ActiveRecord::Base
  has_paper_trail
  is_impressionable :counter_cache => true

  has_many :delegates
  belongs_to :parliament

  attr_accessible :xml_id, :group_id, :first_name, :title, :parliament_id, :impressions_count,
    :vote_count, :yes_count, :no_count, :abstain_count, :absent_count 

  attr_accessor :session3_present, :session3_vote, :session2_present, :session2_vote, :session1_present, :session1_vote

  def self.with_parliament(ids=nil)
    x = includes(:parliament => :parliament_translations)
    if ids.present? && ids.class == Array
      x = x.where(:parliament_id => ids)      
    end
    return x
  end

  def session3_present_formatted
    if read_attribute(:session3_present).present?
      if read_attribute(:session3_present)
        I18n.t('helpers.boolean.y')
      else
        I18n.t('helpers.boolean.n')
      end
    end
  end

  def session3_vote_formatted
    case read_attribute(:session3_vote)
      when 0
        I18n.t('helpers.boolean.abstain')
      when 1
        I18n.t('helpers.boolean.y')
      when 3
        I18n.t('helpers.boolean.n')
      else
        if read_attribute(:parliament_id) == 1
          I18n.t('helpers.links.not_present2')
        else
          I18n.t('helpers.links.not_present')
        end
    end
  end

  def session2_present_formatted
    if read_attribute(:session2_present).present?
      if read_attribute(:session2_present)
        I18n.t('helpers.boolean.y')
      else
        I18n.t('helpers.boolean.n')
      end
    end
  end

  def session2_vote_formatted
    case read_attribute(:session2_vote)
      when 0
        I18n.t('helpers.boolean.abstain')
      when 1
        I18n.t('helpers.boolean.y')
      when 3
        I18n.t('helpers.boolean.n')
      else
        if read_attribute(:parliament_id) == 1
          I18n.t('helpers.links.not_present2')
        else
          I18n.t('helpers.links.not_present')
        end
    end
  end

  def session1_present_formatted
    if read_attribute(:session1_present).present?
      if read_attribute(:session1_present)
        I18n.t('helpers.boolean.y')
      else
        I18n.t('helpers.boolean.n')
      end
    end
  end

  def session1_vote_formatted
    case read_attribute(:session1_vote)
      when 0
        I18n.t('helpers.boolean.abstain')
      when 1
        I18n.t('helpers.boolean.y')
      when 3
        I18n.t('helpers.boolean.n')
      else
        if read_attribute(:parliament_id) == 1
          I18n.t('helpers.links.not_present2')
        else
          I18n.t('helpers.links.not_present')
        end
    end
  end

  # get the delegates that were not present
  def self.available_delegates(agenda_id)
    # get all delegates in the conference
    agenda = Agenda.find_by_id(agenda_id)
    if agenda.present?
      used_delegates = Delegate.joins(:voting_results => :voting_session).select("distinct delegates.xml_id").where("voting_sessions.agenda_id = ?", agenda_id)
      if used_delegates.present?
        AllDelegate.where("parliament_id = ? and xml_id not in (?)", agenda.parliament_id, used_delegates.map{|x| x.xml_id}).order("first_name")
      else
        AllDelegate.where("parliament_id = ?", agenda.parliament_id).order("first_name")
      end
    end
  end

  def self.add_if_new(delegates, parliament_id)
    if delegates.present?
      delegates.each do |delegate|
        exists = AllDelegate.where(:xml_id => delegate.xml_id, :first_name => delegate.first_name, :parliament_id => parliament_id)

        if !exists.present?
          ad = AllDelegate.create(:xml_id => delegate.xml_id, :first_name => delegate.first_name, :parliament_id => parliament_id)
          # now add id to delegate record
          delegate.all_delegate_id = ad.id if ad.present?
          delegate.save
        end
      end
    end
  end

  def self.passed_laws_voting_history(xml_id, start_date=nil, end_date=nil)
    x = nil
    if xml_id.present?
      x = Agenda.includes(:conference => :delegates, :voting_session => :voting_results)
        .public_laws
        .where('delegates.id = voting_results.delegate_id and delegates.xml_id = ?', xml_id)

      if start_date.present?
        x = x.where('conferences.start_date >= ?', start_date)
      end
      if end_date.present?
        x = x.where('conferences.start_date <= ?', end_date)
      end
    end

    return x
  end

  def self.votes_for_passed_law(agenda_public_url_id, get_all_3_sessions="true", search=nil, sort_col=nil, sort_dir=nil, limit=nil, offset=nil)
    x = []
    a = Agenda.includes(:conference).public_laws.find_by_public_url_id(agenda_public_url_id)

    if a.present?
      sql = "select ad.id, ad.first_name, ad.parliament_id, s3.present as session3_present, s3.vote as session3_vote " 
      if get_all_3_sessions == "true"
        sql << ", s2.present as session2_present, s2.vote as session2_vote, s1.present as session1_present, s1.vote as session1_vote "
      end
      sql << "from all_delegates as ad "
      sql << "left join  (select d.all_delegate_id, vr.present, vr.vote from delegates as d inner join voting_results as vr on vr.delegate_id = d.id inner join voting_sessions as vs on vs.id = vr.voting_session_id where vs.agenda_id = :session3_id "
      sql << ") as s3 on s3.all_delegate_id = ad.id "
      if get_all_3_sessions == "true"
        sql << "left join  (select d.all_delegate_id, vr.present, vr.vote from delegates as d inner join voting_results as vr on vr.delegate_id = d.id inner join voting_sessions as vs on vs.id = vr.voting_session_id where vs.agenda_id = :session2_id "
        sql << ") as s2 on s2.all_delegate_id = ad.id "
        sql << "left join  (select d.all_delegate_id, vr.present, vr.vote from delegates as d inner join voting_results as vr on vr.delegate_id = d.id inner join voting_sessions as vs on vs.id = vr.voting_session_id where vs.agenda_id = :session1_id "
        sql << ") as s1 on s1.all_delegate_id = ad.id "
      end
      sql << "where ad.parliament_id = :parliament_id "
      if search.present?
        sql << "and ad.first_name like :search "
      end
      if sort_col.present? && sort_dir.present?
        sql << "order by #{sort_col} #{sort_dir} "
      end      
      if limit.present?
        sql << "limit #{limit} "
      end      
      if offset.present?
        sql << "offset #{offset} "
      end      

      x = find_by_sql([sql, :session3_id => a.id, :session2_id => a.session_number2_id, :session1_id => a.session_number1_id, 
                :parliament_id => a.parliament_id,
                :search => "%#{search}%"])

    end
    return x
  end

  def self.update_vote_counts(parliament_id)
    # total votes
    x = passed_laws_vote_count(parliament_id)
    if x.present?
      update(x.map{|x| x.id}, x.map{|x| {"vote_count" => x.vote_count}}) 
    else
      # no laws are public so make sure vote counts are 0
      where(:parliament_id => parliament_id).update_all(:vote_count => 0)
    end

    # yes votes
    x = passed_laws_yes_count(parliament_id)
    if x.present?
      update(x.map{|x| x.id}, x.map{|x| {"yes_count" => x.vote_count}}) 
    else
      # no laws are public so make sure vote counts are 0
      where(:parliament_id => parliament_id).update_all(:yes_count => 0)
    end

    # no votes
    x = passed_laws_no_count(parliament_id)
    if x.present?
      update(x.map{|x| x.id}, x.map{|x| {"no_count" => x.vote_count}}) 
    else
      # no laws are public so make sure vote counts are 0
      where(:parliament_id => parliament_id).update_all(:no_count => 0)
    end

    # abstain votes
    x = passed_laws_abstain_count(parliament_id)
    if x.present?
      update(x.map{|x| x.id}, x.map{|x| {"abstain_count" => x.vote_count}}) 
    else
      # no laws are public so make sure vote counts are 0
      where(:parliament_id => parliament_id).update_all(:abstain_count => 0)
    end

    # absent votes
    x = passed_laws_absent_count(parliament_id)
    if x.present?
      update(x.map{|x| x.id}, x.map{|x| {"absent_count" => x.vote_count}}) 
    else
      # no laws are public so make sure vote counts are 0
      where(:parliament_id => parliament_id).update_all(:absent_count => 0)
    end

  end

  def self.merge_delegates(id_to_keep, id_to_remove)
    if id_to_keep.present? && id_to_remove.present?
      AllDelegate.transaction do
        to_keep = AllDelegate.includes(:delegates => :voting_results).where(:id => id_to_keep)
        to_remove = AllDelegate.includes(:delegates => :voting_results).where(:id => id_to_remove)
    
        if to_keep.present? && to_remove.present?
          to_keep_results = to_keep.first.delegates.map{|x| x.voting_results}.flatten

          to_remove.first.delegates.each do |del|
puts "delegate id #{del.id}"          
            update_del_id = false
            del.voting_results.each do |vr|
puts "- voting record id #{vr.id}"          
              # if to_keep does not have a vote for this session, add it
              # if it does have a vote, assume want to keep the vote for the to_keep record
              if to_keep_results.index{|x| vr.voting_session_id == x.voting_session_id}.nil?
puts "-- need to copy vote result"          
                # see if delegate record exists for this conference
                to_keep_delegate = to_keep.first.delegates.select{|x| x.conference_id == del.conference_id}
                # if records exists, update vote results record with this id
                # otherwise update to_remove del id to reference id_to_keep
                if to_keep_delegate.present?
puts "--- delegate exists for to keep, just updating vote result record"          
                  # record exists, update vote results record to use to_keep del id
                  vr.delegate_id = to_keep_delegate.first.id
                  vr.save
                else
puts "--- delegate record not exists"          
                  # update to_remove delegate to reference id_to_keep
                  # - this is actually done after for loop so that
                  #   no errors occur due to changing the id before finished 
                  #   going through all vote records of this delegate
                  update_del_id = true
                end
              end
            end        
            if update_del_id
puts "---* updating delegate record to be for record to_keep"          
              del.all_delegate_id = to_keep.first.id
              del.first_name = to_keep.first.first_name
              del.xml_id = to_keep.first.xml_id
              del.group_id = to_keep.first.xml_id
              del.title = to_keep.first.title
              del.save
            end
          end
        end
        
        # now delete the delegate/voting result records for to_remove
puts "********** deleting records"          
        del_ids = Delegate.select('id').where(:all_delegate_id => id_to_remove)
        VotingResult.where(:delegate_id => del_ids.map{|x| x.id}).delete_all
        Delegate.where(:id => del_ids.map{|x| x.id}).delete_all
        AllDelegate.delete(id_to_remove)

        # update vote counts
puts "********** updating vote counts"          
        AllDelegate.update_vote_counts(to_keep.first.parliament_id)
      end
    end
  end
  
protected

  def self.passed_laws_vote_count_query
    sql = "select ad.id, ad.first_name, count(*) as vote_count "
    sql << "from all_delegates as ad "
    sql << "inner join delegates as d on d.all_delegate_id = ad.id "
    sql << "inner join conferences as c on c.id = d.conference_id "
    sql << "inner join agendas as a on a.conference_id = c.id "
    sql << "inner join voting_sessions as vs on vs.agenda_id = a.id "
    sql << "inner join voting_results as vr on vr.voting_session_id = vs.id and vr.delegate_id = d.id "
    sql << "inner join upload_files as uf on uf.id = c.upload_file_id "
    sql << "where a.is_law = 1 and a.is_public = 1 and vs.passed = 1 and uf.is_deleted = 0 and a.public_url_id is not null and a.public_url_id != '' "
    sql << "and ad.parliament_id = :parl_id "
    sql << "[placeholder] "    
    sql << "group by ad.id, ad.first_name"
  end

  def self.passed_laws_vote_count(parliament_id)
    sql = passed_laws_vote_count_query.gsub('[placeholder]', 'and vr.present = 1')
    find_by_sql([sql, :parl_id => parliament_id])
  end

  def self.passed_laws_yes_count(parliament_id)
    sql = passed_laws_vote_count_query.gsub('[placeholder]', 'and vr.vote = 1 and vr.present = 1')
    find_by_sql([sql, :parl_id => parliament_id])
  end

  def self.passed_laws_no_count(parliament_id)
    sql = passed_laws_vote_count_query.gsub('[placeholder]', 'and vr.vote = 3 and vr.present = 1')
    find_by_sql([sql, :parl_id => parliament_id])
  end

  def self.passed_laws_abstain_count(parliament_id)
    sql = passed_laws_vote_count_query.gsub('[placeholder]', 'and vr.vote = 0 and vr.present = 1')
    find_by_sql([sql, :parl_id => parliament_id])
  end

  def self.passed_laws_absent_count(parliament_id)
    sql = passed_laws_vote_count_query.gsub('[placeholder]', 'and vr.present = 0')
    find_by_sql([sql, :parl_id => parliament_id])
  end

end

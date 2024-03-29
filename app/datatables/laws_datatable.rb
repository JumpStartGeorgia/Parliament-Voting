class LawsDatatable
  include Rails.application.routes.url_helpers
  delegate :params, :h, :link_to, :number_to_currency, :number_with_delimiter, to: :@view
  delegate :current_user, to: :@current_user

  def initialize(view, current_user)
    @view = view
    @current_user = current_user
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: Agenda.not_deleted.not_public.final_laws.count,
      iTotalDisplayRecords: agendas.total_entries,
      aaData: data
    }
  end

private

  def data
    agendas.map do |agenda|
      [
        link_to(agenda.official_law_title.present? ? agenda.official_law_title : agenda.name, 
          admin_agenda_path(:id => agenda.id, :locale => I18n.locale)),
        agenda.law_title,
        agenda.law_description,
        agenda.registration_number,
        agenda.voting_session.nil? ? nil : "#{agenda.voting_session.passed_formatted} (#{agenda.total_yes} / #{agenda.total_no} / #{agenda.total_abstain})",
        has_law_ids(agenda),
        has_session1(agenda),
        has_session2(agenda),
        can_publish(agenda)
      ]
    end
  end

  def has_law_ids(agenda)
    x = ''

    ## 2014-03-17 turning this off since parliament.ge website no longer has text

#    x = link_to(agenda.law_id.present? && agenda.law_url.present? ? I18n.t('helpers.links.edit') : I18n.t('helpers.links.add'), 
#      admin_edit_agenda_path(:id => agenda.id, :return_to => Agenda::MAKE_PUBLIC_PARAM, :locale => I18n.locale), 
#      :class => 'btn btn-mini btn-danger fancybox_live')

    x = link_to(agenda.law_id.present? ? I18n.t('helpers.links.edit') : I18n.t('helpers.links.add'), 
      admin_edit_agenda_path(:id => agenda.id, :return_to => Agenda::MAKE_PUBLIC_PARAM, :locale => I18n.locale), 
      :class => 'btn btn-mini btn-danger fancybox_live')

#    if agenda.law_id.present? && agenda.law_url.present?
    if agenda.law_id.present?
      x << "<br /><br />".html_safe
      x << link_to(I18n.t('helpers.links.view'), agenda.law_url, :target => :blank, :class => 'btn btn-mini')
    end


    return x
  end

  def has_session1(agenda)
    x = ''
    if agenda.session_number.index(Agenda::FINAL_VERSION[0]).nil?
      x << link_to(agenda.session_number1_id.present? ? I18n.t('helpers.links.edit') : I18n.t('helpers.links.add'), 
        admin_session_match_path(:agenda_id => agenda.id, :session => "#{Agenda::PREFIX[3]} #{Agenda::CONSISTENT_SESSION_NAME[1]}", :locale => I18n.locale), 
        :class => 'btn btn-mini btn-danger fancybox_live')

      if agenda.session_number1_id.present?
        x << "<br /><br />".html_safe
        x << link_to(I18n.t('helpers.links.view'), 
          admin_agenda_path(:id => agenda.session_number1_id, :locale => I18n.locale), 
          :class => 'btn btn-mini')
      end
    end
    return x
  end

  def has_session2(agenda)
    x = ''
    if agenda.session_number.index(Agenda::FINAL_VERSION[0]).nil?
      x << link_to(agenda.session_number2_id.present? ? I18n.t('helpers.links.edit') : I18n.t('helpers.links.add'), 
        admin_session_match_path(:agenda_id => agenda.id, :session => "#{Agenda::PREFIX[2]} #{Agenda::CONSISTENT_SESSION_NAME[1]}", :locale => I18n.locale), 
        :class => 'btn btn-mini btn-danger fancybox_live')

      if agenda.session_number2_id.present?
        x << "<br /><br />".html_safe
        x << link_to(I18n.t('helpers.links.view'), admin_agenda_path(:id => agenda.session_number2_id, :locale => I18n.locale), :class => 'btn btn-mini')
      end

    end
    return x
  end

  def can_publish(agenda)
    ## 2014-03-17 turning this off since parliament.ge website no longer has text

#    if agenda.law_id.present? && agenda.law_url.present? && (agenda.session_number.index(Agenda::FINAL_VERSION[0]).present? ||
    if agenda.law_id.present? && (agenda.session_number.index(Agenda::FINAL_VERSION[0]).present? ||
      (agenda.session_number1_id.present? && agenda.session_number2_id.present?))
      link_to(I18n.t('helpers.links.publish'), admin_make_public_path(:id => agenda.id, :locale => I18n.locale), :class => 'btn btn-mini btn-success')
    end
  end



  def agendas
    @agendas ||= fetch_agendas
  end

  def fetch_agendas
    agendas = Agenda.not_deleted.not_public.final_laws.order("#{sort_column} #{sort_direction}")
    agendas = agendas.page(page).per_page(per_page)
    if params[:sSearch].present?
      agendas = agendas.where("agendas.name like :search or agendas.description like :search", search: "%#{params[:sSearch]}%")
    end
    agendas
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : 10
  end

  def sort_column
    columns = %w[agendas.official_law_title agendas.law_title agendas.law_description agendas.registration_number voting_sessions.passed agendas.law_id agendas.session_number1_id agendas.session_number2_id agendas.official_law_title]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end

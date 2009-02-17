class ItemsController < ApplicationController
  
  before_filter :logged_in, :except => [ :index, :show, :search]
  
  def index
    fetch_items
  end
  
  def show
    @title = URI.unescape(params[:id])
    #OPTIMIZE Is here two separate BD calls, could these be done in one time?
    @items = Item.find(:all, :conditions => ["title = ? AND status <> 'disabled'", @title.capitalize])
    fetch_items
    render :action => :index
  end
  
  def edit
    @editable_item = Item.find(params[:id])
    return unless must_be_current_user(@editable_item.owner)
    @person = Person.find(params[:person_id])
    show_profile
    render :template => "people/show" 
  end
  
  def update
    @person = Person.find(params[:person_id])
    if params[:item][:cancel]
      redirect_to person_path(@person) and return
    end  
    @item = Item.find(params[:id])
    return unless must_be_current_user(@item.owner)
    @item.title = params[:item][:title]
    if @item.save
      flash[:notice] = :item_updated
    else 
      flash[:error] = :item_could_not_be_updated
    end    
    redirect_to person_path(@person)
  end
  
  def create
    @item = Item.new(params[:item])
    if @item.save
      flash[:notice] = :item_added  
      respond_to do |format|
        format.html { redirect_to @current_user }
        format.js  
      end
    else 
      flash[:error] = :item_could_not_be_added 
      redirect_to @current_user
    end
  end  
  
  def destroy
    @item = Item.find(params[:id])
    return unless must_be_current_user(@item.owner)
    @item.disable
    flash[:notice] = :item_removed
    redirect_to @current_user
  end
  
  def search
    save_navi_state(['items', 'search_items'])
    if params[:q]
      query = params[:q]
      begin
        s = Ferret::Search::SortField.new(:title_sort, :reverse => false)
        items = Item.find_by_contents(query, {:sort => s}, {:conditions => "status <> 'disabled'"})
        @items = items.paginate :page => params[:page], :per_page => per_page
      end
    end
  end
  
  def borrow
    @person = Person.find(params[:person_id])
    @item = Item.find(params[:id])
    return unless must_not_be_current_user(@item.owner, :cant_borrow_from_self)
  end
  
  def thank_for
    @item = Item.find(params[:id])
    return unless must_not_be_current_user(@item.owner, :cant_thank_self_for_item)
    @person = Person.find(params[:person_id])
    @kassi_event = KassiEvent.new
    @kassi_event.realizer_id = @person.id
  end
  
  def mark_as_borrowed
    @item = Item.find(params[:kassi_event][:eventable_id])
    return unless must_not_be_current_user(@item.owner, :cant_thank_self_for_item)
    create_kassi_event
    flash[:notice] = :thanks_for_item_sent
    @person = Person.find(params[:person_id])    
    redirect_to @person
  end
  
  private
  
  def fetch_items
    save_navi_state(['items','browse_items','',''])
    @letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖ".split("")
    @item_titles = Item.find(:all, :conditions => "status <> 'disabled'", :select => "DISTINCT title", :order => 'title ASC').collect(&:title)
  end
  
end

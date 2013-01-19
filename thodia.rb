# encoding: utf-8
###############################################################################
# START HERE: Tutorial for scraping ASP.NET pages (HTML pages that end .aspx), using the
# very powerful Mechanize library. In general, when you follow a 'next' link on 
# .aspx pages, you're actually submitting a form.
# This tutorial demonstrates scraping a particularly tricky example. 
###############################################################################
require 'mechanize'
require 'securerandom'
require 'json'

#http://thodia.vn/websites/SearchResult.aspx?loNameID=1&lo=hcm
BASE_URL = 'http://thodia.vn/websites/'

# scrape_table function: gets passed an individual page to scrape (not important for tutorial)
def scrape_table(page_body)
  data_table = Nokogiri::HTML(page_body).css('table div.ItemResult').collect.with_index do |row, index|
    place_rec = {}
    main_cat_rec = {}
    sub_cat_rec = {}
    place_cat_rel_rec = {}
    main_cat_id = -9999
    sub_cat_id = -9999
    address = ""

    # create a place id
    place_id = SecureRandom.uuid
    title_links = row.css('div#HotspotResult_Info').css('a')

    address = row.xpath('//span[contains(@id, "_lblAddress")]')[index].inner_text
    address.gsub!(/\\u([\da-fA-F]{4})/) {|m| [$1].pack("H*").unpack("n*").pack("U*")}
    address.strip!
    address.gsub!("Địa chỉ: ", "")

    # see if the place has already been saved, if so, move on to the next
    #saved_places = ScraperWiki.select("name, address from Places")
    #place_already_saved = saved_places.any?  {|h| h["Name"] == title_links[0].inner_text && h["Address"] == address}
    place_already_saved = rec_exists?("places", ["name", "address"], {"name" => title_links[0].inner_text, "address" => address})
    p place_already_saved
    next if place_already_saved

    # main cat info
    unless title_links[1].nil? 
      main_cat_rec['name'] = title_links[1].inner_text
      main_cat_id = title_links[1]["href"].match(/.*CategoryID=(.*?)&.*/)[1]
      main_cat_id = main_cat_id.nil? ? -9999 : main_cat_id
      main_cat_rec['id'] = main_cat_id

      # save the main cat info for this row
      write("main_cats", ["name"], main_cat_rec.to_s + ",")
      #ScraperWiki.save_sqlite(["MainCat"], main_cat_rec, "MainCats")
    end
    # sub cat info
    (2..title_links.count).each do |i|
      unless title_links[i].nil? 
        sub_cat_name = title_links[i].inner_text
        sub_cat_name.gsub!(", ", "")
        sub_cat_rec['name'] = sub_cat_name

        next if title_links[i]["href"].nil? 
        kd = title_links[i]["href"].match(/.*kd=(.*?)$/)
        sub_cat_id = kd[1] unless kd.nil? 
        sub_cat_id = sub_cat_id.nil? ? -9999 : sub_cat_id
        #p sub_cat_id
        #p main_cat_id
        sub_cat_rec['id'] = sub_cat_id
        sub_cat_rec['main_cat_id'] = main_cat_id
        write("sub_cats", ["id", "main_cat_id"], sub_cat_rec.to_s + ",")
        #ScraperWiki.save_sqlite(["SubCat", "MainCatId"], sub_cat_rec, "SubCats")

        # add a new record to place - cat - relation table
        place_cat_rel_rec["place_id"] = place_id
        place_cat_rel_rec["main_cat_id"] = main_cat_id
        place_cat_rel_rec["sub_cat_id"] = sub_cat_id
        write("place_cat_rels", ["place_id", "sub_cat_id", "main_cat_id"], place_cat_rel_rec.to_s + ",")
        #ScraperWiki.save_sqlite(["PlaceId", "SubCatId", "MainCatId"], place_cat_rel_rec, "PlaceCatRelation")
      end
    end
    # place's info
    unless title_links[0].nil? 
      place_rec["id"] = place_id
      place_rec['name'] = title_links[0].inner_text
      place_rec["address"] = address
      p place_rec['name']
       
      # getting phone number, website, hours, parking info
      item_page_link = title_links[0]["href"]
      p item_page_link
      # since their db is mixed up with all locations in one place
      # save this link so that we can sort them out easily later
      # "http://thodia.vn/khach-san-thuy-van-vung-tau.html"
      # "http://thodia.vn/khach-san-thuy-van-ha-noi.html
      # "http://thodia.vn/khach-san-thuy-van-ho-chi-minh.html
      place_rec["tho_dia_link"] = item_page_link

      item_page = Nokogiri::HTML(@br.get(item_page_link).body)
      phone = item_page.xpath("//span[contains(@id, '_lbTel')]").inner_text
      email = item_page.xpath("//span[contains(@id, '_lbEmail')]").inner_text
      website = item_page.xpath("//a[contains(@id, '_lblWebsite')]").first
      website = website.nil? ? "" : website.inner_text
      tag_list = ""
      tag_all = item_page.xpath("//div[contains(@id, '_dvListTag')]").children
      tag_all.each do |tag|
        # in the form of "<span>blah</span>", "<span>, </span>", "<span> blah</span>"
        tag_list += tag.text
      end
    
      #p phone, email, website
      #p tag_list
    
      place_rec["phone"] = phone
      place_rec["email"] = email
      place_rec["website"] = website
      place_rec["tag_list"] = tag_list
      
      write("places", ["id", "name"], place_rec.to_s + ",")
      #ScraperWiki.save_sqlite(["PlaceId", "Name"], place_rec, "Places")
    end
  end
end

# Scrape page, look for 'next' link: if found, submit the page form
def scrape_and_look_for_next_link(page, request_url, next_page_num)
  while add_position(next_page_num).nil? do
    next_page_num += 1
  end
  
  link = page.link_with(:text => 'Tiếp')
  if link
    got_page = @br.get request_url
    view_state = got_page.forms[0].field_with(:name => "__VIEWSTATE").value
    #p view_state
    page.form_with(:id => 'aspnetForm') do |f|
      f['__EVENTTARGET'] = 'ctl00$ContentPlaceHolder1$ucPaging$lkbNext'
      f['__EVENTARGUMENT'] = ''
      f['__LASTFOCUS'] = ''
      f['__VIEWSTATE'] = view_state
      f['viet_method'] = 'on'
      f['ctl00$Header$ucSearch$txtSearch'] = 'Tìm địa điểm, thông tin khuyến mãi, hàng giảm giá...'
      f['ctl00$ContentPlaceHolder1$hdfPage'] = next_page_num
      f['ctl00$ContentPlaceHolder1$hdfKey'] = ''
      f['ctl00$ContentPlaceHolder1$hdfKey1'] = ''
      f['ctl00$ContentPlaceHolder1$hdfLocation'] = -1
      f['ctl00$ContentPlaceHolder1$hdf_usseachResult'] = 0
      f['ctl00$ucPopUpThank$dlstThanks$ctl00$RadbThank'] = 1
      f['ctl00$ucPopUpThank$hdfThankID'] = 1
      f['ctl00$ucPopUpThank$ucPopUpThank$hdfText'] = ''
      f['ctl00$ucPopUpThank$txtMessage'] = ''
      f['ctl00$hdfFreUserID'] = ''
      f['ctl00$hdfThankForPU'] = ''
      f['ctl00$hdfIDTemplate'] = ''
      page = f.submit()
    end
    scrape_table(page.body)
    scrape_and_look_for_next_link(page, request_url, next_page_num + 1)
  end
end

def write(file_name, unique_keys, data, options = {})
  mode = (!options.empty? && options[:overwrite]) ? "w" : "a"
  open(file_name + ".json", mode) do |f|
    unless rec_exists?(file_name, unique_keys, data)
      f.puts data
    end
  end
end

def rec_exists?(file_name, unique_keys, data)
  json = File.read(file_name + ".json")
  json = json.split(",\n")
  data = data.to_s
  data = eval data.gsub("},", "}")
  json.each do |h|
    h = eval h
    flag = true
    unique_keys.each do |k|
      if h[k.to_s].to_s != data[k.to_s].to_s
        flag = false
      end
    end # end unique keys loop
    if flag == true
      #p "rec exists!!!!!!!"
      return true
    end
  end # end json loop
  #p "doesn't exist, safe to move on"
  false
end

def add_position(pos)
  return nil if position_already_saved? pos
  positions = read_positions
  positions << pos.to_i
  p positions
  positions.sort!
  positions.join("\n")
  open("current_position.json", "w") do |f|
    f.puts positions
  end
  true
end

def position_already_saved?(pos)
  read_positions.include?(pos)
end

def get_last_position
  gaps = get_gaps(read_positions)
  gaps.first.to_i unless gaps.empty?
  read_positions.last.to_i + 1 unless read_positions.empty?
  1
end

def read_positions
  positions = File.read("current_position.json")
  return [] if positions.empty?
  positions = positions.split("\n") # build an array of positions
  positions = positions.collect {|p| p.to_i}
  positions.sort!
end

def get_gaps (array)
  return [] if array.empty?
  (array.first .. array.last).to_a - array
end

# ---------------------------------------------------------------------------
# START HERE: setting up Mechanize
# We need to set the user-agent header so the page thinks we're a browser, 
# as otherwise it won't show all the fields we need
# ---------------------------------------------------------------------------



starting_url = BASE_URL + 'SearchResult.aspx?loNameID=1&lo=hcm'
@br = Mechanize.new
@br.keep_alive = false
@br.user_agent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.0.1) Gecko/2008071615 Fedora/3.0.1-1.fc9 Firefox/3.0.1'

page = @br.get(starting_url)
p page.body

# Have a look at 'page': note the 'onSubmit' JavaScript function that is called when 
# you click on the 'next' link. We'll mimic this in the function above.

# create places table first
#ScraperWiki.sqliteexecute("create table Places(Name, Address)")
# start scraping
scrape_and_look_for_next_link(page, starting_url, get_last_position <= 1 ? 1 : get_last_position - 1)
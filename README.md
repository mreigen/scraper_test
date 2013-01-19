scraper_test
============

Parallel processing scraper to scrape ASP NET pages using mechanize and nokogiri

TODO list:
- Add file lock (flock) to prevent to processes writing data on the same file at the same time. I had 9 processes parsing the site and I have no conflict problem.
- Right now the counter increment only 1 for each iteration, we should make this 10 or a larger number so that the chance of conflict is smaller.
- Add specs
- This is important: Add another counter for interrupted scrapes, we can save this in another counter file or in the same "current_positions.json". The purpose of this is to scrape the pages that were interrupted in the middle next time we run a process. This file may contain an array of "bad" pages:

For example I ran 10 processes and there wewasre a network problem so below are the pages they were on right on the time of the "disaster" happened:

23
67
37
89
167
225
356
367
367
368

When the processes start again, I want them to go back to this list first to finish up the pages. So in the program, instead of grabbing the last position in the current_posisions.json right away, check the interrupted positions first, finish them first then move on to the current_posisions.json.

- Another thing is to generalize the program so that anyone can run this to scrape any ASP.NET site. All they need to provide is a set of rules and settings. For example:

scrape_rules = {
  data: {
    places : { name: "div#HotspotResult_Info a", address: "//span[contains(@id, "_lblAddress")]" },
    categories : { name : "blah rules" … }
  }
}

But this may not be practical since each of us has a different need for different sites and each site has a different structure of HTML. So if anyone want to use this code they can change the scrape_body function to do what they want, it should be very easy and straight forward.
 
All of the above are easy to do but I don't have time yet and I ran 16 processes last night and they gave me 89000 records (for all tables) out of 900 pages so I have gotten the whole's site data which is what I need. I will come back to this at a later time.

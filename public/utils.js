function expire_passphrase() {
  var whoami = "nobody";
  // Expire passphrase
  var data = JSON.parse(localStorage.getItem('vaultpassphrase'));
  if(data != null) {
    var ts = data.ts,
        now = new Date().getTime();
    if(now > ts) {
      localStorage.removeItem("vaultpassphrase");
    }
    else {
      whoami = encodeURIComponent(data.identity);
    }
  }

  // Patch navigation menu
  $('#navigate_menu').html('<a href="/navigate/' + whoami + '" class="item"><i class="folder open icon"></i></a>');
}

function init_all() {
  expire_passphrase();
}

function get_passphrase_struct() {
  var passphrase_raw = localStorage.getItem("vaultpassphrase");
  if(passphrase_raw == null)
    return null;
  return JSON.parse(passphrase_raw);
}

function refresh_passphrase_status() {
  var remembered = (get_passphrase_struct() == null)  ? "Passphrase: <span class='ko'>Unknown<span>" : "Passphrase: <span class='ok'>Remembered</span>";
  $('#ppstatus').html("<a href='/enterpassphrase'>" + remembered + "</a>");
}

function reset_diag() {
  $('#diag').html('');
}

function display_diag(txt, lf) {
  var ftxt;
  if(lf) ftxt = txt + "<br />"
  else   ftxt = txt;
  $('#diag').html($('#diag').html() + ftxt);
}

function display_flash(txt, type) {
  var html;
  if (type == "positive")
    html = '<div class="ui positive message">' + txt + "</div>";
  else if (type == "error")
    html = '<div class="ui negative message">' + txt + "</div>";

  $('#flash').html(html);

  setTimeout(function() {
    $('#flash').html('');
  }, 5000);
}

function display_more(header, content_id) {
  $.ajax({
    type: "GET",
    url: "/content/" + content_id + ".txt",
    data: {},
    success: function( content ) {
      $('.long.modal .moreheader').text(header);
      $('.long.modal .description').html(content);
      $('.long.modal').modal('show');
    }
  });
}

function display_dimmer(content) {
  $('.page.dimmer .content .txt').html(content);
  $('.page.dimmer').modal('show');
}

function hide_dimmer() {
  // TODO why is semantic ui detaching this guy? (Or so goes the claim in the console...)
  $('.page.dimmer').modal('hide');
}

function display_loader(content) {
  var full_content = '<div class="ui indeterminate text loader">'
    + content
    + '</div>';
  display_dimmer(full_content);
}

function hide_loader(modal) {
  hide_dimmer();
}

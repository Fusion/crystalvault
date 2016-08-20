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
  $('#navigate_menu').html('<a href="/navigate/' + whoami + '" class="item">Navigate</a>');
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

function reset_diag() {
  $('#diag').html('');
}

function display_diag(txt, lf) {
  var ftxt;
  if(lf) ftxt = txt + "<br />"
  else   ftxt = txt;
  $('#diag').html($('#diag').html() + ftxt);
}

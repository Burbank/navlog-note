/* Support form — same pattern as yourMark / GearUp4U. Inbox is never in the HTML. */
(function () {
  document.querySelectorAll(".support-form").forEach(function (form) {
    var status = form.querySelector(".support-status");
    if (!status) return;
    var opened = Date.now();
    var gate = form.elements.namedItem("gate");
    var mark = String(opened ^ 0x5a5a);
    window.setTimeout(function () {
      if (gate) gate.value = mark;
    }, 2800);
    var inbox = function () {
      return [62, 47, 52, 51, 59, 26, 46, 47, 46, 59, 55, 59, 51, 54, 116, 57, 53, 55]
        .map(function (n) {
          return String.fromCharCode(n ^ 0x5a);
        })
        .join("");
    };
    var postTo = function () {
      return ["https://form", "submit.co/ajax/"].join("") + inbox();
    };
    var coolKey = "ql-note";
    var coolMs = 90 * 1000;
    var say = function (text) {
      status.hidden = false;
      status.textContent = text;
    };
    var fakeOk = function () {
      say("Sent. Thank you.");
      form.reset();
      if (gate) gate.value = "";
    };
    form.addEventListener("submit", function (event) {
      event.preventDefault();
      var data = new FormData(form);
      var bait =
        String(data.get("website") || "").trim() ||
        String(data.get("company") || "").trim();
      if (bait) {
        fakeOk();
        return;
      }
      if (Date.now() - opened < 2800 || !gate || gate.value !== mark) {
        say("Please wait a moment, then press Send again.");
        return;
      }
      var last = Number(sessionStorage.getItem(coolKey) || 0);
      if (last && Date.now() - last < coolMs) {
        say("Please wait a minute before sending another note.");
        return;
      }
      var name = String(data.get("name") || "").trim();
      var email = String(data.get("email") || "").trim();
      var message = String(data.get("message") || "").trim();
      if (name.length < 1 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || message.length < 3) {
        say("Name, email, and a short message are needed.");
        return;
      }
      say("Sending…");
      fetch(postTo(), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json"
        },
        body: JSON.stringify({
          name: name,
          email: email,
          message: message,
          _subject: "QUICKLOG support — " + name,
          _template: "box",
          _captcha: false,
          _honey: ""
        })
      })
        .then(function (res) {
          return res
            .json()
            .then(function (json) {
              return { res: res, json: json };
            })
            .catch(function () {
              return { res: res, json: {} };
            });
        })
        .then(function (result) {
          if (!result.res.ok || result.json.success === "false" || result.json.success === false) {
            say(result.json.message || "Could not send. Try again in a moment.");
            return;
          }
          sessionStorage.setItem(coolKey, String(Date.now()));
          form.reset();
          if (gate) gate.value = mark;
          say("Sent. Thank you.");
        })
        .catch(function () {
          say("Could not send. Try again in a moment.");
        });
    });
  });
})();

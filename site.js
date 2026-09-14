/* Assemble contact mail at runtime, same pattern as FDP FMS. */
(function () {
  document.querySelectorAll(".email-link").forEach(function (link) {
    var user = link.getAttribute("data-user");
    var domain = link.getAttribute("data-domain");
    if (!user || !domain) return;
    var email = user + "@" + domain;
    link.href = "mailto:" + email;
    link.textContent = email;
    link.removeAttribute("data-user");
    link.removeAttribute("data-domain");
  });
})();

#' Authenticate user credentials
#'
#' \code{auth} asks the API's server for a session ID (SID), which you can then
#' pass along to either \code{\link{query_wos}} or \code{\link{pull_wos}}. Note,
#' there are limits on how many session IDs you can get in a given period of time
#' (roughly 5 SIDs in a 5 minute period).
#'
#' @param username Your username. Specify \code{username = NULL} if you want to
#' use IP-based authentication.
#' @param password Your password. Specify \code{password = NULL} if you want to
#' use IP-based authentication.
#'
#' @return A session ID
#'
#' @examples
#' \dontrun{
#'
#' # Pass user credentials in manually:
#' auth("some_username", password = "some_password")
#'
#' # Use the default of looking for username and password in envvars, so you
#' # don't have to keep specifying them in your code:
#' Sys.setenv(WOS_USERNAME = "some_username", WOS_PASSWORD = "some_password")
#' auth()
#'}
#' @export
auth <- function(username = Sys.getenv("WOS_USERNAME"),
                 password = Sys.getenv("WOS_PASSWORD")) {
  ip_based <- is.null(username) && is.null(password)

  if (!ip_based) {
    if (username == "" || password == "") {
      stop(
        "You need to provide a username and password to use the API",
        call. = FALSE
      )
    }
  }

  body <-
    '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:auth="http://auth.cxf.wokmws.thomsonreuters.com">
    <soapenv:Header/>
    <soapenv:Body>
    <auth:authenticate/>
    </soapenv:Body>
    </soapenv:Envelope>'

  url <- "http://search.webofknowledge.com/esti/wokmws/ws/WOKMWSAuthenticate"

  # Send HTTP POST request
  if (is.null(username) && is.null(password)) {
    response <- httr::POST(
      url,
      body = body,
      httr::timeout(30),
      ua()
    )
  } else {
    auth_val <- get_authorization_value(username, password)
    response <- httr::POST(
      url,
      body = body,
      httr::add_headers(Authorization = auth_val),
      httr::timeout(30),
      ua()
    )
  }

  # Confirm server didn't throw an error
  check_resp(response)

  # Pull out SID from XML
  doc <- get_xml(response)
  parse_el_txt(doc, xpath = "//return")
}

get_authorization_value <- function(username, password) {
  string <- paste0(username, ":", password)
  raw <- charToRaw(string)
  paste("Basic", base64enc::base64encode(raw))
}

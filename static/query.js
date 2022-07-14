fetch('/static/query-input.html')
    .then(response => response.text())
    .then(text => document.getElementById('navbar').innerHTML += text);

function RunQuery(query, url) {
    url + "?" + query;
}

function GetQueryFromUrl(url) {
    return ""
}

document.getElementById('query-input').text = GetQueryFromUrl()
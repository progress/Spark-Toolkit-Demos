


tryGetServerInfo();

document.getElementById('ManageApps').addEventListener('click', function() {
	document.location = '/manager';
});

document.getElementById('ManagePAS').addEventListener('click', function() {
	document.location = '/oemanager/';
});

function tryGetUrl(url) {

	var xhr = new XMLHttpRequest();
	xhr.onload = function () {
		if (xhr.status !== 200) {
			// Let the caller handle a null object return value
			// throw new Error();
			updateServerInfo(null);
		} else {
			var jsonObject = JSON.parse(xhr.responseText);
			updateServerInfo(jsonObject);
		}

	}
	xhr.open('GET', url, true);
	xhr.send(null);
}

function tryGetServerInfo() {

	try {
		tryGetUrl('../server');
	} catch (e) {

	}
}

function updateServerInfo(jsonObject) {

	var apsv = document.getElementById('apsv');
	var soap = document.getElementById('soap');
	var rest = document.getElementById('rest');
	var manager = document.getElementById('manager');

	if (jsonObject) {
		document.getElementById('OEVersion').innerHTML = sanitizeInput(jsonObject.ServerInfo.OEVersion);
		document.getElementById('TCVersion').innerHTML = sanitizeInput(jsonObject.ServerInfo.TomcatVersion);
		document.getElementById('JVMVendor').innerHTML = sanitizeInput(jsonObject.ServerInfo.JVMVendor);
		document.getElementById('JVMVersion').innerHTML = sanitizeInput(jsonObject.ServerInfo.JVMVersion);
		document.getElementById('PASVersion').innerHTML = sanitizeInput(jsonObject.ServerInfo.PASVersion);
		document.getElementById('OSName').innerHTML = sanitizeInput(jsonObject.ServerInfo.OSName);
		document.getElementById('OSVersion').innerHTML = sanitizeInput(jsonObject.ServerInfo.OSVersion);
		document.getElementById('OSArch').innerHTML = sanitizeInput(jsonObject.ServerInfo.OSArch);
		document.getElementById('HostName').innerHTML = sanitizeInput(jsonObject.ServerInfo.HostName);
		document.getElementById('IPAddress').innerHTML = sanitizeInput(jsonObject.ServerInfo.IPAddress);
		document.getElementById('upTime').innerHTML = "Server has been running for " + sanitizeInput(jsonObject.UpTime);
	} else {
		// The serverAlert element does not exist
		// document.getElementById('serverAlert').innerHTML = 'Server status
		// information is disabled';
		document.getElementById('OEVersion').innerHTML = "OpenEdge";
		document.getElementById('TCVersion').innerHTML = "Unavailable";
		document.getElementById('JVMVendor').innerHTML = "Unavailable";
		document.getElementById('JVMVersion').innerHTML = "Unavailable";
		document.getElementById('PASVersion').innerHTML = "Unavailable";
		document.getElementById('OSName').innerHTML = "Unavailable";
		document.getElementById('OSVersion').innerHTML = "Unavailable";
		document.getElementById('OSArch').innerHTML = "Unavailable";
		document.getElementById('HostName').innerHTML = "Unavailable";
		document.getElementById('IPAddress').innerHTML = "Unavailable";
		document.getElementById('upTime').innerHTML = "Server has been running for: Unavailable";
	}
}

function sanitizeInput(str) { return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
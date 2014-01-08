(function(f) {
	if (document.readyState == 'loading')
		document.addEventListener('DOMContentLoaded', f, false);
	else
		f();
})(function() {
	Array.prototype.forEach.call(document.querySelectorAll('a[href]'), function(a) {
		a.addEventListener("mouseover", function() {
			Array.prototype.forEach.call(document.querySelectorAll('a[href="' + a.getAttribute('href') + '"]'), function(a) {
				a.className = 'hover';
			});
		}, false);
		a.addEventListener("mouseout", function() {
			Array.prototype.forEach.call(document.querySelectorAll('a[href="' + a.getAttribute('href') + '"]'), function(a) {
				a.className = '';
			});
		}, false);
	});
})

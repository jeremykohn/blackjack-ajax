$(document).ready(function() {
	player_hit();
	player_stay();
	dealer_next();
});


function player_hit() {
	$(document).on('click', 'form#player_hit input', function(){
		$.ajax({
			type: 'POST',
			url: '/game/player/hit'
		}).done(function(msg) {
			$("#game").replaceWith(msg);
		});	
		return false;
	});
}


function player_stay() {
	$(document).on('click', 'form#player_stay input', function(){
		$.ajax({
			type: 'POST',
			url: '/game/player/stay'
		}).done(function(msg) {
			$("#game").replaceWith(msg);
		});	
		return false;
	});
}


function dealer_next() {	
	$(document).on('click', 'form#dealer_next input', function(){
		$.ajax({
			type: 'POST',
			url: '/game/dealer/next'
		}).done(function(msg) {
			$("#game").replaceWith(msg);
		});	
		return false;
	});
}


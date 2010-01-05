$(function(){
	$('input.delete').click(function(){
		if( ! confirm("Are you sure you want to delete this?") ){
			return false;
		}
	})
})
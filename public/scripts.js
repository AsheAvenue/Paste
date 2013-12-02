var paste = (function(){

    var self;

    return {

        init: function(){
            
            self = this;
            
            //focus the textarea and resize it
            $('#paste_body').focus();
            self.size_textarea();
            
            $(window).on('resize', function(){
                self.size_textarea();
            });
        },

        size_textarea: function() {
            $('#paste_body').height( $(window).height() - $('.footer').height() - $('.navbar').height() - 12);
        }
    };

})();
$(document).ready(function(){
    paste.init();
});

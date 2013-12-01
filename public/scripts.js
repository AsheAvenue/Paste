var paste = (function(){

    var self;

    return {

        init: function(){
            
            self = this;
            
            //focus the textarea and resize it
            $('#pastie_body').focus();
            self.size_textarea();
            
            $(window).on('resize', function(){
                self.size_textarea();
            });
        },

        size_textarea: function() {
            $('#pastie_body').height( $(window).height() - 128);
        }
    };

})();
$(document).ready(function(){
    paste.init();
});

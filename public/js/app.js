

$(function(){
  jQuery.extend({

    getQueryParameters : function(str) {
      return (str || document.location.search).replace(/(^\?)/,'').split("&").map(function(n){return n = n.split("="),this[n[0]] = n[1],this}.bind({}))[0];
    }
  
  });

  function indent(value) {
    var firstCharacter = value.trim().charAt(0)
    try{
      if(['{','['].indexOf(firstCharacter) >= 0){
        return JSON.stringify(JSON.parse(value),null,2);
      } else {
        return value;
      }
    } catch (e) {
      return value;
    }
  }

  $('#report-link').on('click', function(){
    if($('#reportDiv')[0].innerHTML.trim().length === 0){
      $('#reportDiv').load('report');
    }
  });

  $(document.links).filter(function() {
    return this.hostname != window.location.hostname;
  }).attr('target', '_blank');

  $('.sequence-expand-button').click(function (event) {
    let button = $(this);
    if (button.text().indexOf("Show") > -1) {
      button.html("Hide Details");
    }
    else {
      button.html("Show Details");
    }
  });

  $('.sequence-details-more').click(function () {
    var button = $(this);
    var sequence = button.data('sequence');
     if(sequence){
      $('.help-details').each(function(){
        if($(this).data('sequence') === sequence){
          $(this).show();
          $('#help-modal-title').html($(this).data('sequence-title'));
           // FIXME: technically we don't hae to do this every time it is opened, only the first time
          $(this).find('a[href^="http"]').attr('target','_blank');
        } else {
          $(this).hide();
        }
      })
      $('#help-sequence-' + sequence).collapse('show')
       $('#help-modal').modal('show');
     }
  });

  $('.sequence-button').click(function(){
    
    var sequences = [],
        test_cases = [],
        requirements = [],
        popupTitle = "",
        lockedVariables = [];

    popupTitle = $(this).closest('.sequence-action-boundary').data('group');

    $('.input-instructions').hide();
    if($(this).data('groupId')){
      $('#input-instructions-' + $(this).data('groupId')).show();

      let lockedVars = $('#group-lock-variables-' + $(this).data('groupId')).data('lockVariables');
      
      if(lockedVars){
        lockedVariables = lockedVars.split(",")
      }
    }
    

    $(this).closest('.sequence-action-boundary').find('.test-case-data').each(function(){
      sequences.push($(this).data('sequence'));
      test_cases.push($(this).data('testCase'));

      if(!popupTitle){
        popupTitle = $(this).data('testCaseTitle');
      }

    });

    // clear out the existing contents
    $('.prerequisite-group').empty();
    $('.enabled-prerequisite-group-title').hide();
    $('.disabled-prerequisite-group-title').hide();
    $('.disabled-prerequisites').hide();
    $('.enabled-prerequisites').hide();

    //$('input[type=radio][name=confidential_client]').on('change', function() {
    $('#PrerequisitesModal').on('change', function(e) {
      if(e.target.id === 'confidential_client_on_active') {
        $('.client-secret-container').show();
      } else if (e.target.id === 'confidential_client_off_active'){
        $('.client-secret-container').hide();
      }
    });

    $('#PrerequisitesModal .prerequisites-forms > .form-group').each(function(){
      var requiredby = $(this).data('requiredby');
      var definedby = $(this).data('definedby');
      var prerequisite = $(this).data('prerequisite');

      var definedList = [];
      var show = false;
      if(definedby){
        definedby.split(',').forEach(function(item){
          definedList.push(item);
        })
      }
      if(requiredby){
        requiredby.split(',').forEach(function(item){
          if(sequences.includes(item)){
            // this field is required by one of the sequences I'm running
            // is it also defined by one of the sequences?
            var alreadyDefined = false;
            definedList.forEach(function(defined){
              sequences.forEach(function(seq){
                if(defined === seq){
                  alreadyDefined = true;
                }
              })
            })
            if(!alreadyDefined){
              show = true;
              requirements.push(prerequisite)
            }
          }
        })
      }

      if(show){
        let formInput = $(this).clone();
        if(lockedVariables.includes(prerequisite)){
          formInput.find('input').attr('readonly', 'readonly');
          formInput.find(':radio:not(:checked)').attr('disabled', true);
          
          $('.disabled-prerequisites').append(formInput);
          $('.disabled-prerequisite-group-title').show();
          $('.disabled-prerequisites').show();
        } else {
          formInput.find(':radio').each(function(){
            $(this).attr('id', $(this)[0].id + '_active');
          });
        formInput.find('input')[0].removeAttribute('readonly');
        formInput.find(':radio:not(:checked)').attr('disabled', false);
        $('.enabled-prerequisites').append(formInput);
        $('.enabled-prerequisite-group-title').show();
        $('.enabled-prerequisites').show();
        }
        //$(this).show()
      } else {
        //$(this).hide();
      }


      
    });

    $('#PrerequisitesModal input[name=sequence]').val(sequences.join(','));
    $('#PrerequisitesModal input[name=test_case]').val(test_cases.join(','));
    $('#PrerequisitesModal input[name=required_fields]').val(requirements.join(','));

    // Confidential client special case
    
    if($('#confidential_client_on')[0].checked){
       $('.client-secret-container').show();
    } else {
       $('.client-secret-container').hide();
    }
    

    if(requirements.length === 0){
      $('#PrerequisitesModal form').submit();
    } else {
      $('#PrerequisitesModal').modal('show');
    }

    if(popupTitle){
      $('#PrerequisitesModalTitle').html(popupTitle)
    }
  })


  $('.disable-buttons').each(function(){
    $(this).find('.btn').attr('disabled', true)

    $(this).attr('title', $(this).data('preconditionDescription'))
                        .attr('data-toggle','tooltip');
  });

  $('.get-started').click(function(){
    $('#group-link-DiscoveryandRegistration').tab('show')
  })

  $('.test-results-more').on('click', function() {
    if($(this).data('testingInstanceId') && $(this).data('testResultId')){
      var url = window.basePath + '/' + $(this).data('testingInstanceId') + '/test_result/' + $(this).data('testResultId');
      $("#testResultDetailsModal").find('.modal-content').load(url, function(value){
        $(this).find("pre>code").each(function(el){
          let $el = $(this)
          let content = $el.html()
          try{
            if(content && content.length > 0){
              content = indent($el.html())
            }
          } catch (ex) {
            console.log('Error indenting: ' + ex)
          }
          $el.html(content)
        });

        $("#testResultDetailsModal").modal('show');
      })
    }
  })

  $('.test-list .test-list-more').on('click', function() {
    if($(this).data('sequenceName') && $(this).data('testIndex') !== undefined){
      var url = window.basePath + '/test_details/' + $(this).data('module') + '/' + $(this).data('sequenceName') + '/' + $(this).data('testIndex');
      $("#testDetailsModal").find('.modal-content').load(url, function(value){
        $("#testDetailsModal").modal('show');
      })
    }
  })

  $(":input[type=text][readonly='readonly']").on('click', function(){
    this.select();
  })

  if(window.location.hash.length > 0){
    let hashParts = window.location.hash.split('#')[1].split('/');
    let testCasePart = hashParts[0];

    if(hashParts.length > 1) {
      testCasePart = hashParts[1];
      $('#group-link-' + hashParts[0]).tab('show');
    }

    if(testCasePart.length > 0){
      testCasePart.split(',').forEach(function(tc){
        var testCase = $('#' + tc);
        var details = $('#' + tc + '-details');
        details.collapse('show')
        testCase.parents('.sequence-row').find('.sequence-expand-button').text("Hide Details")
      })
    }
  }

  $('[data-toggle="tooltip"]').tooltip()

  $('#WaitModal').modal('show');

  var autoRun = $.getQueryParameters().autoRun;
  if(autoRun) {
    var url = window.location.pathname;
    window.history.replaceState({}, null, url);
    $("button[data-sequence='" + autoRun + "']").click()
  }

  // Create a handler to handle the animation of the logo
  function handleScroll(_) {
    /* remove the animation duration if we are loaded to the middle of the page because it is distracting */
    /* using set timeout to reset it so when the user scrolls transitions are enabled. */
    if(_ === null){
      $('.server-info img, .server-name').addClass('no-transition')
      setTimeout(function(){$('.server-info img, .server-name').removeClass('no-transition')}, 500);
    }
    if($(window).scrollTop() > 80) {
      $('.server-info').addClass('show-logo')
    }
    else {
      $('.server-info').removeClass('show-logo')
    }
  }
  // Need to call it for when we initially load
  handleScroll(null)
  // Then register the handler
  $(window).on('scroll', handleScroll)

  $('#preset-select').on('change', function() {
    var uri = $('#preset-select option:selected').data('uri');
    $el = $('input[name=fhir_server]');
    $el.val(uri);
    $el.prop('readonly', uri !== '');
  });

}); 

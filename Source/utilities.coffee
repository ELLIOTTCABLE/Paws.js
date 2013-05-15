module.exports =
utilities =
   
   # This is the most robust method I could come up with to detect the presence or absence of
   # `__proto__`-style accessors. It's probably not foolproof.
   hasPrototypeAccessors: do ->
      canHaz = undefined
      return (setTo) ->
         if (typeof setTo != 'undefined') # FIXME: CoffeeScriptize this.
            canHaz = setTo
         
         return canHaz ? do ->
            (a = new Object).inherits = true
            (b = new Object).__proto__ = a
            return canHaz = !!b.inherits
   
   runInNewContext: do ->
      server = (source, context) ->
         `//@browserify-ignore`
         require('vm').createScript(source).runInNewContext(context)
      
      client = (source, context) ->
         semaphore =
            source: source
         
         $frame = window.document.createElement 'iframe'
         $frame.style.display = 'none'
         body(html(window.document)).insertBefore $frame
         $window = $frame.contentWindow
        #$window.document.close()
         
         $window.__fromSemaphore = semaphore
         $script = $window.document.createElement 'script'
         $script.text = "window.__fromSemaphore.result = eval(window.__fromSemaphore.source)"
         body(html($window.document)).insertBefore $script
         
         body(html(window.document)).removeChild $frame
         
         return semaphore.result
      
      nodeFor = (type) -> (node) ->
         node.getElementsByTagName(type)[0] or
         node.insertBefore (node.ownerDocument or node).createElement type
      
      html = nodeFor('html')
      head = nodeFor('head')
      body = nodeFor('body')

      return (source, context) ->
         (if process?.browser then client else server).apply this, arguments
   
   # This creates a pseudo-‘subclass’ of a native JavaScript complex-type. Currently only makes
   # sense to run on `Function`.
   # 
   # There's several ways to acheive a trick like this; unfortunately, all of them are severely
   # limited in some crucial way. Herein, I chose two of the most flexible ways, and dynamically
   # choose which to employ based on the capabilities of the hosting JavaScript implementation.
   # ---
   # FIXME: This currently only works for subclassing `Function`, genearlize it out
   # FIXME: The runtime choice between the two implementations is unnecessary
   # TODO: Release this as its own micro-library
   subclass: do ->
      noop = ->
      
      # The first approach, and most flexible of all, is to create `Function` instances with the
      # native `Function` constructor from our own context, and then directly modify the
      # `[[Prototype]]` field thereof with the `__proto__` pseudo-property provided by many
      # implementations.
      # ---
      # FIXME: This should probably try to use standard ES5 methods instead of `__proto__`
      withAccessors = (parent, constructorBody, runtimeBody, intactArguments) ->
         constructor = ->
            that = ->
               body = arguments.callee._runtimeBody ? runtimeBody ? noop
               body[if intactArguments then 'call' else 'apply'] this, arguments
            that.__proto__ = constructor.prototype
            return (constructorBody ? noop).apply(that, arguments) ? that
         
         constructor.prototype = do ->
            C = new Function; C.prototype = parent.prototype; new C
         constructor.prototype.constructor = constructor
         
         constructor
         
      # This approach, while more widely supported (see `runInNewContext`), has a major downside:
      # it results in instances of the returned ‘subclass’ *do not inherit from the local context's
      # `Object` or `Function`.* This means that modifications to `Object.prototype` and similar
      # will not be accessible on instances of the returned subclass.
      # 
      # This is not considered to be too much of a downside, as 1. the vast majority of JavaScript
      # programmers and widely-used JavaScript libraries consider modifying `Object.prototype` to be
      # anathema *already*, and so their code won't be affected by this shortcoming; 2. this
      # downside only applies in environments where `hasPrototypeAccessors` evaluates to `false`
      # (notably, Internet Explorer); and 3. this downside only applies to *our* objects (instances
      # of the returned subclass). I, elliottcable, consider it fairly unlikely for a situation to
      # arise where all of the following are true:
      # 
      #  - A consumer of the Paws API,
      #  - wishes their code to operate in old Internet Explorers,
      #  - while *also* using a library that modifies `Object.prototype`,
      #  - and necessitates utilizing those modifications on objects returned from our APIs.
      # 
      # (All that ... along with the fact that I know of absolutely *no way* to circumvent this.)
      fromOtherContext = (parent, constructorBody, runtimeBody, intactArguments) ->
         parent = utilities.runInNewContext parent.name
         parent.runtimeBody = runtimeBody
         
         constructor = ->
            that = new parent("
               return (arguments.callee._runtimeBody || "+parent.name+".runtimeBody || function(){})
                  [intactArguments ? 'call':'apply'](this, arguments)")
            (constructorBody ? noop).apply(that, arguments) ? that
         
         constructor.prototype = parent.prototype
         constructor.prototype.constructor = constructor
         
         constructor
      
      return (parent, constructorBody, runtimeBody, intactArguments) ->
         (if utilities.hasPrototypeAccessors() then withAccessors else fromOtherContext)
            .apply this, arguments

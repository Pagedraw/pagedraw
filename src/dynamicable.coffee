_l = require 'lodash'
{assert, memoize_on} = require './util'
{nameForType, subtypeOf, Model} = require './model'

# This is so people can ask foo instanceof GenericDynamicable
# which will be true iff foo is of type Dynamicable(A)
exports.GenericDynamicable = class GenericDynamicable extends Model

# Dynamicable is a way to make data types (like String, Boolean, or more complex)
# dynamicable. This means that a designer can set a staticValue in the editor but
# that default Value will be overwriten by the compiler with some
# Developer specified code if isDynamic is set
# Dynamicable :: Type -> Type
#
# NOTE: If B inherits from A,
# an object of type Dynamicable(B) is not instanceof Dynamicable(A)
# and subtypeOf(Dynamicable(B), Dynamicable(A)) == false
# even though subtypeOf(B, A) == true
#
# This is similar to the behavior in C++/Java/C# per
# https://docs.oracle.com/javase/tutorial/extra/generics/subtype.html
dynamicableCache = {}
exports.Dynamicable = Dynamicable = (A) ->
    cls_name = "dyn(#{nameForType(A)})"
    memoize_on dynamicableCache, cls_name, ->
        Model.register cls_name, class DynamicableImpl extends GenericDynamicable
            # if isDynamic == true, code becomes the value that will replace staticValue
            # at compile time
            properties:
                staticValue: A
                code: String
                isDynamic: Boolean

            constructor: (json) ->
                super(json)
                @code ?= ''
                @isDynamic ?= false
                @source = this

            @from: (staticValue) -> new this({staticValue, isDynamic: false, code: ""})

            @A: A # Dynamicable(String).A == String

            # We include source :: Dynamicable A in the return value of mapStatic so users of this function
            # can find the initial Dynamicable that gave rise to the mappings. This is useful for i.e. mutating
            # the code of a dynamicable that was mapStatic'd in the props getDynamics sidebar
            derivedWith: (members) -> _l.extend @cloneWith(members), {@source}
            mapStatic: (fn) -> @derivedWith(staticValue: fn(@staticValue))


            ## Utility functions for when our internal repr doesn't line up with the JS thing.
            #  FIXME these need to support more than just JS and CJSX

            stringified: -> @derivedWith
                staticValue: String(@staticValue)
                code: "String\(#{@code}\)"

            cssImgUrlified: -> @derivedWith
                staticValue: "url('#{@staticValue}')"
                code: "\"url('\"+(#{@code})+\"')\""

            strTrueOrUndefined: ({templateLang}) -> @derivedWith
                staticValue: if @staticValue then "true" else undefined
                code: switch templateLang
                    # ANGULAR TODO: Might be wrong
                    when 'React', 'JSX', 'TSX', 'Angular2' then "(#{@code}) ? 'true' : undefined"
                    when 'CJSX' then "if (#{@code}) then 'true' else undefined"
                    else
                        # Only React is supported (for now).  Crash in dev, but be silently wrong in dev.
                        # Where's still like 18 docs that use Jinja2, and it's better for them to silently fail than crash.
                        # We don't care about those 18 docs.
                        assert -> false
                        ""



            linearGradientCssTo: (endColor, direction) ->
                code_for_dynamicable = (dyn) ->
                    if dyn.isDynamic then dyn.code else JSON.stringify(dyn.staticValue)

                blah = new (Dynamicable String)({
                    staticValue: "linear-gradient(#{direction.staticValue}deg, #{this.staticValue}, #{endColor.staticValue})"
                    code: "\"linear-gradient(\"+\"(#{code_for_dynamicable direction})\"+\"deg, \"+(#{code_for_dynamicable this})+\", \"+(#{code_for_dynamicable endColor})+\")\""
                    isDynamic: this.isDynamic or endColor.isDynamic or direction.isDynamic
                })
                # FIXME technically the source is *both* [this, endColor]
                blah.source = this
                return blah

            # ANGULAR TODO: might be wrong
            getPropCode: (name, language) ->
                switch language
                    when 'JSX', 'React', 'CJSX', 'TSX' then "this.props.#{name}"
                    when 'Angular2' then "this.#{name}"
                    else "" # HTML doesn't support dynamics


# ugh. At least the ugliness is all concentrated here so folks can just use CodeType
# whenever you want an "always dynamic" dynamicable
Dynamicable.code = (code) -> new (Dynamicable String)({staticValue: '', isDynamic: true, code})
Dynamicable.CodeType = (Dynamicable String)

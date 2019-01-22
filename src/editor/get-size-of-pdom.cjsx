React = require 'react'
createReactClass = require 'create-react-class'
ReactDOM = require 'react-dom'
{assert} = require '../util'
{WindowContextProvider, pdomToReact} = require './pdom-to-react'

check = 0

exports.mountReactElement = mountReactElement = (element, mount_point) ->
    check = 1

    # This assumes ReactDOM.render is synchronous so we can synchronously return.  This
    # assumption might not be true in future versions of React so I'm adding a test that
    # throws if you try to update our version of React. (GLG 07/05/2017)
    #
    # NOTE: We used to wrap element in a GeometryGetter component and wait for componentDidMount
    # React has a weird behavior where componentDidMount gets fired *before* the child error boundary finishes
    # rerendering after catching the error. Now we have to call ReactDOM.render and do ReactDOM.findDOMNode after
    # it because that's the only way we can do this synchronously.
    component = ReactDOM.render element, mount_point, ->
        if check != 1
            throw new Error('Get size of react element is not synchronous')
        check = 2

    if check != 2
        throw new Error('Get size of react element is not synchronous')
    check = 0

    assert -> ReactDOM.findDOMNode(component)?

    return ReactDOM.findDOMNode(component)

getSizeOfReactElement = (element, mount_point) ->
    retVal = mountReactElement(element, mount_point).getBoundingClientRect()
    ReactDOM.unmountComponentAtNode(mount_point)
    return retVal


exports.getSizeOfPdom = getSizeOfPdom = (pdom, offscreen_node) ->
    getSizeOfReactElement(<WindowContextProvider window={window}>{pdomToReact(pdom)}</WindowContextProvider>, offscreen_node)

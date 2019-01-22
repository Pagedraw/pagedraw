React = require 'react'
ReactDOM = require 'react-dom'
_l = require 'lodash'

{Helmet} = require 'react-helmet'

{ModalComponent, registerModalSingleton} = require '../../frontend/modal'
createReactClass = require 'create-react-class'


pages = {
    library_landing: -> require('./landing')
    library_page: -> require('./show')
}

AppWrapper = createReactClass
    render: ->
        Route = pages[@props.route]()
        <div>
            <Helmet>
                <link rel="stylesheet" type="text/css" href="#{window.pd_config.static_server}/library.css" />
                <link rel="stylesheet" href="#{window.pd_config.static_server}/bootstrap-namespaced.css" />
            </Helmet>
            <div>
                <ModalComponent ref="modal" />
                <Route {...window.pd_params} />
            </div>
        </div>

    componentDidMount: ->
        registerModalSingleton(@refs.modal)

ReactDOM.render(<AppWrapper route={window.pd_params.route} />, document.getElementById('app'))

import actions from '../actions'
import { unim } from '../util'
import { connect } from 'nuclear-js-react-addons-chefsplate'
import { data_age } from '../util'
import PropTypes from 'prop-types'
import moment from 'moment'
import { Link } from '@rq/react-easy-router'
import Immutable from 'seamless-immutable'
import preventDefaultWrapper from '@rq/prevent-default-wrapper'
import _ from 'underscore'
import React from 'react'
import Store from '../store'
import { mapProps } from '@rq/react-map-props'

export default
class GithubRepo extends React.Component {
  render() {
    return <div>
    <h1>{this.props.params.repo_name}</h1>
    </div>
  }
}

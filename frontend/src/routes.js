import Handlers from './handlers'
import AppBase from './app'

export default {
  Locations: { path: '/', component: Handlers.Home, wrapper: AppBase },
}

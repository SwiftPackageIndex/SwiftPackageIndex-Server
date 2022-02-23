import { Application } from '@hotwired/stimulus'
import { OverflowingListController } from './overflowing_list_controller.js'

const application = Application.start()
application.register('overflowing-list', OverflowingListController)

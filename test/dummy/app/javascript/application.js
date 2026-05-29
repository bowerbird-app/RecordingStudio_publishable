// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "controllers"
import { application } from "controllers/application"

import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import "recording_studio_attachable/tiptap/attachment_image_addon"

import { Application } from "@hotwired/stimulus";
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";

eagerLoadControllersFrom("controllers", application);

window.Stimulus = application;

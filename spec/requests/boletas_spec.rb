require 'rails_helper'

RSpec.describe "Boletas", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/boletas/index"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/boletas/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/boletas/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/boletas/edit"
      expect(response).to have_http_status(:success)
    end
  end

end

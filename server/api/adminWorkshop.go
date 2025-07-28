package api

import (
	"nachna/core"
	"nachna/database"
	"nachna/models/request"
	"nachna/service/admin"
	"nachna/service/admin/studio"
	"nachna/utils"
	"net/http"
)

func GetAdminService() (admin.AdminService, *core.NachnaException) {
	databaseImpl, err := database.MongoDBDatabaseImpl{}.GetInstance()
	if err != nil {
		return nil, err
	}
	webBasedStudio := studio.WebBasedStudioImpl{}.GetInstance()
	adminStudioService := studio.AdminStudioServiceImpl{}.GetInstance(webBasedStudio, databaseImpl)
	adminService := admin.AdminServiceImpl{}.GetInstance(adminStudioService)
	return adminService, nil
}

func RefreshWorkshops(r *http.Request) (any, *core.NachnaException) {
	adminWorkshopRequest := &request.AdminWorkshopRequest{}
	err := adminWorkshopRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()
	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}
	return adminService.RefreshWorkshops(adminWorkshopRequest)
}

func RefreshStudios(r *http.Request) (any, *core.NachnaException) {
	adminStudioRequest := &request.AdminStudioRequest{}
	err := adminStudioRequest.FromJSON(r.Body)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()
	adminService, err := GetAdminService()
	if err != nil {
		return nil, err
	}
	return adminService.RefreshStudios(adminStudioRequest)
}

func init() {
	Router.HandleFunc(utils.MakeHandler("/admin/refresh_workshops", RefreshWorkshops)).Methods(http.MethodPost)
	Router.HandleFunc(utils.MakeHandler("/admin/refresh_studios", RefreshStudios)).Methods(http.MethodPost)
}

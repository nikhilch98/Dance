package api

import (
	"nachna/core"
	"nachna/models/request"
	"nachna/utils"
	"net/http"
	"nachna/service/admin"
)

func GetAdminService() admin.AdminService {
	return &admin.AdminServiceImpl{}
}

func RefreshWorkshops(r *http.Request) (any, *core.NachnaException) {
    adminWorkshopRequest := &request.AdminWorkshopRequest{}
	err := adminWorkshopRequest.FromJSON(r.Body)
	if err != nil { 
		return nil, err
	}
	defer r.Body.Close()
	adminService := GetAdminService()
	adminService.RefreshWorkshops(adminWorkshopRequest)
	return nil, nil
}

func init() {
	Router.HandleFunc(utils.MakeHandler("/admin/refresh_workshops", RefreshWorkshops)).Methods(http.MethodPost)
}

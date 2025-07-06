package api

import (
	"nachna/core"
	"nachna/models/request"
	"nachna/utils"
	"net/http"
	"nachna/service/admin"
	"nachna/service/admin/studio"
)

func GetAdminService() admin.AdminService {
	danceInnStudio := studio.DanceInnStudioImpl{}.GetInstance("https://danceinn.studio/workshops/upcoming-workshops/", "dance.inn.bangalore", "https://rzp.io/rzp/", 2, 5)
	adminStudioService := studio.AdminStudioServiceImpl{}.GetInstance(danceInnStudio)
	adminService := admin.AdminServiceImpl{}.GetInstance(adminStudioService)
	return adminService
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

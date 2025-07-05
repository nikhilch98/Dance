package admin

import (
	"fmt"
	"nachna/core"
	"nachna/models/request"
)

type AdminService interface {
	RefreshWorkshops(request *request.AdminWorkshopRequest) (any, *core.NachnaException)
}

type AdminServiceImpl struct {
}

func (a *AdminServiceImpl) RefreshWorkshops(request *request.AdminWorkshopRequest) (any, *core.NachnaException) {
	fmt.Println("RefreshWorkshops called with request for studio id", request.StudioId)
	return nil, nil
}

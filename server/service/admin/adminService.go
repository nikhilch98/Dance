package admin

import (
	"nachna/core"
	"nachna/models/request"
	"nachna/service/admin/studio"
	"sync"
)

type AdminService interface {
	GetInstance(adminStudioServiceImpl studio.AdminStudioService) AdminService
	RefreshWorkshops(request *request.AdminWorkshopRequest) (any, *core.NachnaException)
}

var lock = &sync.Mutex{}

type AdminServiceImpl struct {
	adminStudioService studio.AdminStudioService
}

var adminServiceImpl *AdminServiceImpl

func (AdminServiceImpl) GetInstance(adminStudioServiceImpl studio.AdminStudioService) AdminService {
	if adminServiceImpl == nil {
		lock.Lock()
		defer lock.Unlock()
		if adminServiceImpl == nil {
			adminServiceImpl = &AdminServiceImpl{
				adminStudioService: adminStudioServiceImpl,
			}
		}
	}
	return adminServiceImpl
}

func (a *AdminServiceImpl) RefreshWorkshops(request *request.AdminWorkshopRequest) (any, *core.NachnaException) {
	return a.adminStudioService.RefreshWorkshopsGivenStudioId(request.StudioId)
}

#include <MailCore/MCCore.h>

extern "C" {
	#include "CObject.h"

	CObject newCObjectWithRange(uint64_t start, uint64_t end) {
	    CObject indexSet;
	    indexSet.self = reinterpret_cast<void *>(new mailcore::Object());
	    return indexSet;
	}

	void deleteCObject(CObject indexSet) {
	    delete reinterpret_cast<mailcore::Object *>(indexSet.self);
	}
}
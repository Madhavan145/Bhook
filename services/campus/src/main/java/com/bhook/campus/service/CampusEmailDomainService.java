package com.bhook.campus.service;

import com.bhook.campus.api.dto.DomainLookupResponse;
import com.bhook.campus.api.dto.EmailDomainRequest;
import com.bhook.campus.api.dto.EmailDomainResponse;
import com.bhook.campus.domain.Campus;
import com.bhook.campus.domain.CampusEmailDomain;
import com.bhook.campus.repository.CampusEmailDomainRepository;
import com.bhook.campus.repository.CampusRepository;
import com.bhook.common.error.BhookException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class CampusEmailDomainService {

    private final CampusRepository campusRepository;
    private final CampusEmailDomainRepository repository;

    @Transactional
    public EmailDomainResponse addDomain(UUID campusId, EmailDomainRequest req) {
        Campus campus = campusRepository.findById(campusId)
                .orElseThrow(() -> BhookException.notFound("Campus not found"));

        String normalized = req.domain().toLowerCase();
        repository.findByCampusIdAndDomain(campus.getId(), normalized).ifPresent(existing -> {
            throw BhookException.conflict("Domain already configured for this campus");
        });

        CampusEmailDomain saved = repository.save(CampusEmailDomain.builder()
                .campusId(campus.getId())
                .domain(normalized)
                .membershipType(req.membershipType())
                .autoVerify(req.autoVerify())
                .notes(req.notes())
                .status("ACTIVE")
                .build());
        return toResponse(saved);
    }

    @Transactional
    public List<EmailDomainResponse> addDomains(UUID campusId, List<EmailDomainRequest> requests) {
        if (requests == null || requests.isEmpty()) return List.of();
        return requests.stream().map(r -> addDomain(campusId, r)).toList();
    }

    @Transactional(readOnly = true)
    public List<EmailDomainResponse> listForCampus(UUID campusId) {
        return repository.findByCampusIdOrderByDomainAsc(campusId).stream()
                .map(this::toResponse).toList();
    }

    @Transactional
    public void archive(UUID campusId, UUID domainId) {
        CampusEmailDomain domain = repository.findById(domainId)
                .orElseThrow(() -> BhookException.notFound("Email domain not found"));
        if (!domain.getCampusId().equals(campusId)) {
            throw BhookException.forbidden("Domain does not belong to this campus");
        }
        domain.setStatus("ARCHIVED");
        repository.save(domain);
    }

    @Transactional(readOnly = true)
    public DomainLookupResponse lookupByEmail(String email) {
        if (email == null || !email.contains("@")) {
            throw BhookException.validation("Email is required");
        }
        String domain = email.substring(email.indexOf('@') + 1).toLowerCase();
        List<CampusEmailDomain> hits = repository.findByDomainAndStatus(domain, "ACTIVE");
        List<DomainLookupResponse.Match> matches = hits.stream()
                .map(h -> {
                    String campusName = campusRepository.findById(h.getCampusId())
                            .map(Campus::getDisplayName).orElse(null);
                    return new DomainLookupResponse.Match(h.getCampusId(), campusName, h.getMembershipType(), h.isAutoVerify());
                })
                .toList();
        return new DomainLookupResponse(domain, matches);
    }

    private EmailDomainResponse toResponse(CampusEmailDomain e) {
        return new EmailDomainResponse(
                e.getId(),
                e.getCampusId(),
                e.getDomain(),
                e.getMembershipType(),
                e.isAutoVerify(),
                e.getStatus(),
                e.getNotes(),
                e.getCreatedAt(),
                e.getUpdatedAt()
        );
    }
}

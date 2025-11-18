package io.bytebakehouse.train.company.orchestrator.entity.converter;

import io.bytebakehouse.train.company.orchestrator.entity.enums.DocumentType;
import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter(autoApply = true)
public class DocumentTypeConverter implements AttributeConverter<DocumentType, String> {

    @Override
    public String convertToDatabaseColumn(DocumentType attribute) {
        return attribute == null ? null : attribute.name();
    }

    @Override
    public DocumentType convertToEntityAttribute(String dbData) {
        return dbData == null ? null : DocumentType.valueOf(dbData);
    }
}
